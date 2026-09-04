/*
 * Copyright (c) 2026 Meltytech, LLC
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
import QtQml.Models
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Shotcut.Controls as Shotcut
import "LayerTimeline.js" as Logic

// A Canva/CapCut-style, layer-based alternative to timeline.qml. Every
// element (video, image, text, shape, audio) is one MLT track presented as
// a full-width, independently draggable/trimmable "layer" row -- there is no
// waveform-dense multi-clip-per-track editing here, by design. It talks to
// the exact same TimelineDock/MultitrackModel API as the classic view (see
// ../timeline/timeline.qml), so nothing about the underlying project or MLT
// model differs between the two -- only the presentation.
//
// Toggle between this and the classic view from the Timeline panel's menu
// (Settings.timelineLayerView / Actions["timelineToggleLayerViewAction"]).
Rectangle {
    id: root

    property int headerWidth: 170
    property real rowHeight: 56
    property int rulerHeight: 26
    property alias trackCount: layerRepeater.count
    // '', 'above', or 'below': see dragging()/dropZone below.
    property string newLayerZone: ''
    // Layer a dragged element would land on, or -1 while it stays on its own.
    property int hoverTargetTrack: -1
    // Live landing preview for the element currently being dragged.
    property bool dragPreviewActive: false
    property int dragPreviewStart: 0
    property int dragPreviewDuration: 0
    property int dragPreviewTrack: 0
    property color dragPreviewTint: '#2D9CC4'
    // Shared offset applied to every selected element during a group drag.
    property int dragDeltaFrames: 0
    property int dragDeltaLayers: 0

    color: activePalette.window
    focus: true

    SystemPalette {
        id: activePalette
    }

    Keys.onPressed: event => {
        if ((event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) && timeline.selection.length > 0) {
            // liftSelection() removes every selected element and leaves the
            // surrounding timing alone, which is what a layer editor wants.
            timeline.liftSelection();
            event.accepted = true;
        } else if (event.key === Qt.Key_A && (event.modifiers & Qt.ControlModifier)) {
            timeline.selectAll();
            event.accepted = true;
        } else if (event.key === Qt.Key_D && (event.modifiers & Qt.ControlModifier) && timeline.selection.length === 1) {
            const p = timeline.selection[0];
            root.duplicateElement(p.y, p.x);
            event.accepted = true;
        }
    }

    // Clicking an element that is already part of a multi-selection must keep
    // that selection, otherwise dragging a group would collapse it to one.
    function selectBlock(trackIndex, clipIndex, modifiers) {
        const already = Logic.selectionContains(trackIndex, clipIndex);
        if (modifiers & (Qt.ControlModifier | Qt.ShiftModifier)) {
            let selection = [];
            for (let i = 0; i < timeline.selection.length; i++) {
                const p = timeline.selection[i];
                if (!(p.x === clipIndex && p.y === trackIndex))
                    selection.push(Qt.point(p.x, p.y));
            }
            if (!already)
                selection.push(Qt.point(clipIndex, trackIndex));
            timeline.selection = selection;
            return;
        }
        if (already && timeline.selection.length > 1)
            return;
        timeline.selection = [Qt.point(clipIndex, trackIndex)];
    }

    // Rubber-band selection. x/y/w/h are in the tracks area's content
    // coordinates, the same space blocks are laid out in.
    function selectInRect(x, y, w, h) {
        let selection = [];
        for (let t = 0; t < rowRepeater.count; t++) {
            const rowTop = t * root.rowHeight;
            if (rowTop + root.rowHeight < y || rowTop > y + h)
                continue;
            const row = rowRepeater.itemAt(t);
            if (!row)
                continue;
            for (let c = 0; c < row.clipCount; c++) {
                const b = row.blockAt(c);
                if (!b || b.isBlank)
                    continue;
                if (b.clipPx + b.clipPxW < x || b.clipPx > x + w)
                    continue;
                selection.push(Qt.point(c, t));
            }
        }
        timeline.selection = selection;
    }

    function addLayer(isAudioLayer) {
        const idx = isAudioLayer ? timeline.addAudioTrack() : timeline.addVideoTrack();
        timeline.currentTrack = idx;
    }

    function adjustZoom(factor) {
        multitrack.scaleFactor = Math.max(0.002, Math.min(50, multitrack.scaleFactor * factor));
    }

    // Copy the element and drop the copy immediately after itself. overwrite()
    // rather than insert(), so the rest of the layer does not ripple sideways.
    function duplicateElement(trackIndex, clipIndex) {
        const row = rowRepeater.itemAt(trackIndex);
        const b = row ? row.blockAt(clipIndex) : null;
        if (!b || b.isBlank)
            return;
        timeline.copy(trackIndex, clipIndex);
        timeline.overwrite(trackIndex, b.clipStart + b.clipDuration, '', false);
    }

    // Snap a dragged element's start frame to the playhead, the origin, or any
    // other element's edges -- what makes aligning things by hand feel exact.
    function snapFrame(frame, duration, skipTrack, skipClip) {
        if (!settings.timelineSnap)
            return Math.max(0, Math.round(frame));
        const tolerance = 10 / multitrack.scaleFactor;
        let best = Math.round(frame);
        let bestDistance = tolerance;
        function consider(candidateStart) {
            if (candidateStart < 0)
                return;
            const distance = Math.abs(candidateStart - frame);
            if (distance < bestDistance) {
                bestDistance = distance;
                best = Math.round(candidateStart);
            }
        }
        // Align this element's head, or its tail, with each snap target.
        function considerTarget(target) {
            consider(target);
            consider(target - duration);
        }
        considerTarget(0);
        considerTarget(timeline.position);
        for (let t = 0; t < rowRepeater.count; t++) {
            const row = rowRepeater.itemAt(t);
            if (!row)
                continue;
            for (let c = 0; c < row.clipCount; c++) {
                if (t === skipTrack && c === skipClip)
                    continue;
                const other = row.blockAt(c);
                if (!other || other.isBlank)
                    continue;
                considerTarget(other.clipStart);
                considerTarget(other.clipStart + other.clipDuration);
            }
        }
        return Math.max(0, best);
    }

    // ---- Ruler: time ticks + click/drag-to-seek ----
    Rectangle {
        id: rulerArea

        x: root.headerWidth
        y: 0
        width: Math.max(0, root.width - root.headerWidth)
        height: root.rulerHeight
        color: activePalette.base
        clip: true

        readonly property real minTickSpacing: tickMetrics.boundingRect('00:00:00').width + 16
        readonly property real intervalFrames: profile.fps * Math.max(1, Math.ceil(minTickSpacing / (profile.fps * multitrack.scaleFactor)))
        readonly property real tickSpacing: intervalFrames * multitrack.scaleFactor
        readonly property int firstTick: tickSpacing > 0 ? Math.max(0, Math.floor(tracksFlickable.contentX / tickSpacing) - 1) : 0
        readonly property int tickCount: tickSpacing > 0 ? Math.ceil((tracksFlickable.width + tickSpacing * 3) / tickSpacing) : 0

        FontMetrics {
            id: tickMetrics
        }

        Repeater {
            model: rulerArea.tickCount

            Rectangle {
                readonly property int tickIndex: index + rulerArea.firstTick

                anchors.bottom: parent.bottom
                height: 7
                width: 1
                color: activePalette.mid
                x: tickIndex * rulerArea.tickSpacing - tracksFlickable.contentX

                Label {
                    anchors.left: parent.right
                    anchors.leftMargin: 3
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 8
                    font.pixelSize: 10
                    color: activePalette.windowText
                    text: application.clockFromFrames(parent.tickIndex * rulerArea.intervalFrames + 2).substr(0, 8)
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            function seekTo(x) {
                timeline.position = Math.max(0, Math.round((x + tracksFlickable.contentX) / multitrack.scaleFactor));
            }
            onPressed: mouse => seekTo(mouse.x)
            onPositionChanged: mouse => {
                if (pressed)
                    seekTo(mouse.x);
            }
        }
    }

    Rectangle {
        // Playhead line, spanning the ruler and the layer stack.
        x: root.headerWidth + timeline.position * multitrack.scaleFactor - tracksFlickable.contentX
        y: 0
        z: 60
        width: 1
        // Stops at the layer area so it does not draw across the bottom bar.
        height: rulerArea.height + tracksFlickable.height
        color: '#E0432B'
        visible: x >= root.headerWidth && x <= root.width
    }

    // ---- Layer headers (fixed x, scrolls vertically with the rows) ----
    Flickable {
        x: 0
        y: rulerArea.height
        width: root.headerWidth
        height: Math.max(0, root.height - rulerArea.height - addLayerBar.height)
        contentY: tracksFlickable.contentY
        contentHeight: headerColumn.height
        interactive: false
        clip: true

        Column {
            id: headerColumn

            Repeater {
                id: layerRepeater

                model: multitrack

                LayerHead {
                    width: root.headerWidth
                    height: root.rowHeight
                    trackIndex: index
                    trackName: typeof model.name !== 'undefined' ? model.name : ''
                    isAudio: typeof model.audio !== 'undefined' ? model.audio : false
                    isHidden: typeof model.hidden !== 'undefined' ? model.hidden : false
                    isLocked: typeof model.locked !== 'undefined' ? model.locked : false
                    isCurrent: index === timeline.currentTrack

                    onClicked: timeline.currentTrack = index
                    onRenamed: newName => timeline.setTrackName(index, newName)
                    onToggleHidden: timeline.toggleTrackHidden(index)
                    onToggleLocked: timeline.setTrackLock(index, !isLocked)
                    onRemoveRequested: {
                        timeline.currentTrack = index;
                        timeline.removeTrack();
                    }
                    onReorder: direction => {
                        const target = Logic.clamp(index + direction, 0, layerRepeater.count - 1);
                        if (target !== index)
                            timeline.moveTrack(index, target);
                    }
                }
            }
        }
    }

    Rectangle {
        x: 0
        y: rulerArea.height
        width: root.headerWidth
        height: 1
        color: activePalette.mid
    }

    // ---- Layer rows (the actual design canvas) ----
    Flickable {
        id: tracksFlickable

        x: root.headerWidth
        y: rulerArea.height
        width: Math.max(0, root.width - root.headerWidth)
        height: Math.max(0, root.height - rulerArea.height - addLayerBar.height)
        clip: true
        contentWidth: Math.max(width, rowColumn.width + 300)
        contentHeight: Math.max(height, rowColumn.height)
        boundsBehavior: Flickable.StopAtBounds
        // Like the classic view: the Flickable must not compete with a block's
        // own vertical drag, so scrolling goes through the wheel and scrollbars.
        interactive: false

        ScrollBar.horizontal: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        DelegateModel {
            id: layerDelegateModel

            model: multitrack

            LayerRow {
                id: layerRowItem

                model: multitrack
                rootIndex: layerDelegateModel.modelIndex(index)
                // Width comes from the row's own content (see LayerRow); binding
                // it to the Flickable's contentWidth here would be a loop, since
                // contentWidth is derived from this Column's width.
                rowHeight: root.rowHeight
                trackIndex: index
                trackCount: layerRepeater.count
                snapFrame: root.snapFrame
                isAudio: typeof audio !== 'undefined' ? audio : false
                isLocked: typeof locked !== 'undefined' ? locked : false

                onBlockClicked: (clipIndex, modifiers) => {
                    // Selecting only. Opening Properties here would raise the
                    // transition editor -- and spin up its preview producer --
                    // on every single click, which is why that is left to
                    // double-click, the same as every other element.
                    timeline.currentTrack = layerRowItem.trackIndex;
                    root.selectBlock(layerRowItem.trackIndex, clipIndex, modifiers);
                }
                onBlockDoubleClicked: clipIndex => {
                    timeline.currentTrack = layerRowItem.trackIndex;
                    timeline.selection = [Qt.point(clipIndex, layerRowItem.trackIndex)];
                    timeline.openProperties();
                }
                onLayerHoverChanged: targetTrack => {
                    root.hoverTargetTrack = (targetTrack === layerRowItem.trackIndex) ? -1 : targetTrack;
                }
                onDragPreviewChanged: (startFrame, durationFrames, targetTrack, tint, sourceStart, sourceTrack) => {
                    root.dragPreviewStart = startFrame;
                    root.dragPreviewDuration = durationFrames;
                    root.dragPreviewTrack = targetTrack;
                    root.dragPreviewTint = tint;
                    // Everything selected moves by the same amount, so the whole
                    // group can be previewed from the dragged element's delta.
                    root.dragDeltaFrames = startFrame - sourceStart;
                    root.dragDeltaLayers = targetTrack - sourceTrack;
                    root.dragPreviewActive = true;
                }
                onDragPreviewEnded: root.dragPreviewActive = false
            }
        }

        Rectangle {
            // Ghost of where the dragged element will land: exact start, exact
            // duration, on the exact layer. This is the placement hint.
            id: dragGhost

            // Shown for a drag coming from outside (the DropArea reports it, or
            // the mapped drag position from TimelineDock is still arriving). An
            // in-timeline drag is previewed per selected element below instead.
            visible: dropZone.containsDrag || externalDragTimer.running
            x: root.dragPreviewStart * multitrack.scaleFactor
            // A drop aimed above the top layer reports row -1; keep it on screen.
            y: Math.max(0, root.dragPreviewTrack * root.rowHeight + 5)
            // Drags that carry no duration (file manager) still get a visible hint.
            width: Math.max(40, root.dragPreviewDuration * multitrack.scaleFactor)
            height: root.rowHeight - 10
            radius: 8
            color: Qt.rgba(root.dragPreviewTint.r, root.dragPreviewTint.g, root.dragPreviewTint.b, 0.28)
            border.color: '#FFFFFF'
            border.width: 2
            z: 55

            Label {
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: application.timeFromFrames(root.dragPreviewStart)
                color: '#FFFFFF'
                font.pixelSize: 11
                style: Text.Outline
                styleColor: '#000000'
            }
        }

        Repeater {
            // One landing ghost per selected element, so dragging a group shows
            // where the whole group goes -- only the element under the cursor
            // actually moves while dragging.
            model: root.dragPreviewActive ? timeline.selection : []

            Rectangle {
                readonly property var sourceBlock: {
                    const row = rowRepeater.itemAt(modelData.y);
                    return row ? row.blockAt(modelData.x) : null;
                }

                visible: !!sourceBlock && !sourceBlock.isBlank
                x: sourceBlock ? Math.max(0, sourceBlock.clipStart + root.dragDeltaFrames) * multitrack.scaleFactor : 0
                y: Logic.clamp(modelData.y + root.dragDeltaLayers, 0, Math.max(0, rowRepeater.count - 1)) * root.rowHeight + 5
                width: sourceBlock ? Math.max(6, sourceBlock.clipDuration * multitrack.scaleFactor) : 0
                height: root.rowHeight - 10
                radius: 8
                color: sourceBlock ? Qt.rgba(sourceBlock.typeColor.r, sourceBlock.typeColor.g, sourceBlock.typeColor.b, 0.28) : 'transparent'
                border.color: '#FFFFFF'
                border.width: 2
                z: 55

                Label {
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    visible: parent.width > 60
                    text: application.timeFromFrames(Math.max(0, parent.sourceBlock ? parent.sourceBlock.clipStart + root.dragDeltaFrames : 0))
                    color: '#FFFFFF'
                    font.pixelSize: 11
                    style: Text.Outline
                    styleColor: '#000000'
                }
            }
        }

        Rectangle {
            // Highlights the layer a dragged element will land on.
            visible: root.hoverTargetTrack >= 0
            x: tracksFlickable.contentX
            y: root.hoverTargetTrack * root.rowHeight
            width: tracksFlickable.width
            height: root.rowHeight
            color: 'transparent'
            border.color: '#2D9CC4'
            border.width: 2
            radius: 4
            z: 50
        }

        Column {
            id: rowColumn

            Repeater {
                id: rowRepeater

                model: layerDelegateModel
            }
        }

        MouseArea {
            // Behind the rows: click empty space to select that layer and clear
            // the element selection, or drag to rubber-band select across layers.
            id: marqueeArea

            anchors.fill: parent
            z: -1
            property real originX: 0
            property real originY: 0

            onPressed: mouse => {
                originX = mouse.x;
                originY = mouse.y;
                marquee.x = mouse.x;
                marquee.y = mouse.y;
                marquee.width = 0;
                marquee.height = 0;
                marquee.visible = true;
            }
            onPositionChanged: mouse => {
                if (!pressed)
                    return;
                marquee.x = Math.min(originX, mouse.x);
                marquee.y = Math.min(originY, mouse.y);
                marquee.width = Math.abs(mouse.x - originX);
                marquee.height = Math.abs(mouse.y - originY);
            }
            onReleased: mouse => {
                marquee.visible = false;
                if (marquee.width < 4 && marquee.height < 4) {
                    timeline.selection = [];
                    // Children of a Flickable live in its contentItem, so mouse.y
                    // is already a content coordinate -- adding contentY would
                    // double-count.
                    timeline.currentTrack = Logic.clamp(Math.floor(mouse.y / root.rowHeight), 0, Math.max(0, layerRepeater.count - 1));
                    return;
                }
                root.selectInRect(marquee.x, marquee.y, marquee.width, marquee.height);
            }
            onCanceled: marquee.visible = false
        }

        Rectangle {
            id: marquee

            visible: false
            z: 65
            color: Qt.rgba(0.18, 0.61, 0.77, 0.18)
            border.color: '#2D9CC4'
            border.width: 1
        }

        MouseArea {
            // Wheel only (NoButton keeps clicks and drags passing through to the
            // blocks underneath): scroll, Ctrl+wheel zoom, Shift+wheel pan.
            anchors.fill: parent
            z: 70
            acceptedButtons: Qt.NoButton
            // Same convention as the classic timeline: a plain wheel scrolls
            // along the timeline, Alt scrolls between layers, Ctrl zooms.
            onWheel: wheel => {
                const maxX = Math.max(0, tracksFlickable.contentWidth - tracksFlickable.width);
                const maxY = Math.max(0, tracksFlickable.contentHeight - tracksFlickable.height);
                if (wheel.modifiers & Qt.ControlModifier) {
                    root.adjustZoom(wheel.angleDelta.y > 0 ? 1.15 : 1 / 1.15);
                } else if (wheel.pixelDelta.x || wheel.pixelDelta.y) {
                    // Trackpads report both axes.
                    let x = wheel.pixelDelta.x;
                    let y = wheel.pixelDelta.y;
                    if (application.OS !== 'Windows' && !x && y) {
                        x = y;
                        y = 0;
                    }
                    if (!y || Math.abs(x) > 2)
                        tracksFlickable.contentX = Logic.clamp(tracksFlickable.contentX - x, 0, maxX);
                    tracksFlickable.contentY = Logic.clamp(tracksFlickable.contentY - y, 0, maxY);
                } else if (wheel.modifiers & Qt.AltModifier) {
                    tracksFlickable.contentY = Logic.clamp(tracksFlickable.contentY - Math.round(wheel.angleDelta.y / 2), 0, maxY);
                } else {
                    tracksFlickable.contentX = Logic.clamp(tracksFlickable.contentX - Math.round(wheel.angleDelta.y / 2), 0, maxX);
                }
                wheel.accepted = true;
            }
        }

        onWidthChanged: contentX = Math.max(0, Math.min(contentX, contentWidth - width))
    }

    Rectangle {
        // New-layer drop indicator, shown while dragging from Playlist/Source
        // into the empty band above the topmost or below the bottommost row.
        id: newLayerIndicator

        x: root.headerWidth
        y: rulerArea.height + (root.newLayerZone === 'below' ? tracksFlickable.height - height : 0)
        width: Math.max(0, root.width - root.headerWidth)
        height: 12
        visible: root.newLayerZone !== '' && (dropZone.containsDrag || externalDragTimer.running)
        color: '#2D9CC4'
        z: 61

        Label {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: root.newLayerZone === 'above' ? qsTr('Drop here for a new layer on top') : qsTr('Drop here for a new audio layer')
            color: 'white'
            style: Text.Outline
            styleColor: '#000000'
            font.pixelSize: 11
        }
    }

    DropArea {
        id: dropZone

        anchors.fill: tracksFlickable
        // Height of the band at the top/bottom that means "make a new layer".
        readonly property int edge: 16

        function updatePreview(drag) {
            updateAt(drag.x, drag.y, parseInt(drag.text) || 0);
        }

        // x/y are relative to the tracks area (this DropArea's own geometry).
        function updateAt(x, y, durationFrames) {
            const drag = {
                "x": x,
                "y": y
            };
            if (drag.y < edge)
                root.newLayerZone = 'above';
            else if (drag.y > tracksFlickable.height - edge)
                root.newLayerZone = 'below';
            else
                root.newLayerZone = '';
            let targetRow;
            if (root.newLayerZone === 'above') {
                targetRow = -1;
            } else if (root.newLayerZone === 'below') {
                targetRow = layerRepeater.count;
            } else {
                targetRow = Logic.clamp(Math.floor((drag.y + tracksFlickable.contentY) / root.rowHeight), 0, Math.max(0, layerRepeater.count - 1));
                timeline.currentTrack = targetRow;
            }
            // Same ghost the in-timeline drag uses, so a drop from the Playlist
            // shows exactly where and on which layer it will land.
            root.dragPreviewStart = Math.max(0, Math.round((drag.x + tracksFlickable.contentX) / multitrack.scaleFactor));
            root.dragPreviewDuration = durationFrames;
            root.dragPreviewTrack = targetRow;
            root.dragPreviewTint = root.newLayerZone === 'below' ? '#5A9B72' : '#2D9CC4';
        }

        function clearPreview() {
            root.newLayerZone = '';
        }

        onEntered: drag => {
            if (drag.formats.indexOf('application/vnd.mlt+xml') >= 0 || drag.hasUrls) {
                drag.acceptProposedAction();
                updatePreview(drag);
            }
        }
        onExited: clearPreview()
        onPositionChanged: drag => updatePreview(drag)
        onDropped: drop => {
            const position = Math.max(0, Math.round((drop.x + tracksFlickable.contentX) / multitrack.scaleFactor));
            const xml = drop.formats.indexOf('application/vnd.mlt+xml') >= 0 ? drop.getDataAsString('application/vnd.mlt+xml') : drop.urls;
            if (root.newLayerZone !== '')
                timeline.handleDropNewTrack(root.newLayerZone === 'above', position, xml);
            else if (timeline.currentTrack >= 0)
                timeline.handleDrop(timeline.currentTrack, position, xml);
            clearPreview();
            drop.acceptProposedAction();
        }
    }

    // Second, independent source for the drop hint. QQuickWidget does not
    // reliably forward drag events into the QML scene on every platform (Wayland
    // compositors in particular), so TimelineDock also reports the drag with the
    // position already mapped into this view's coordinates. Whichever path is
    // alive drives the same ghost.
    //
    // The hint's lifetime deliberately does NOT use TimelineDock::dropped():
    // that is emitted from the widget's dragLeaveEvent, which fires as soon as
    // the pointer crosses from the dock onto the child QQuickWidget, and would
    // erase the hint the instant it appeared. This timer expires on its own once
    // the drag stops reporting.
    Timer {
        id: externalDragTimer

        interval: 400
    }

    Connections {
        target: timeline

        function onDraggingInView(pos, duration) {
            const x = pos.x - root.headerWidth;
            const y = pos.y - rulerArea.height;
            if (x < 0 || y < 0 || y > tracksFlickable.height) {
                externalDragTimer.stop();
                dropZone.clearPreview();
                return;
            }
            dropZone.updateAt(x, y, duration);
            externalDragTimer.restart();
        }

        function onDropAccepted(xml) {
            externalDragTimer.stop();
            dropZone.clearPreview();
        }
    }

    // ---- Bottom bar: add layer / zoom ----
    Rectangle {
        id: addLayerBar

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 34
        color: activePalette.base

        Rectangle {
            anchors.top: parent.top
            width: parent.width
            height: 1
            color: activePalette.mid
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 6

            ToolButton {
                text: qsTr('+ Layer')
                implicitHeight: 24
                onClicked: root.addLayer(false)

                Shotcut.HoverTip {
                    text: qsTr('Add a new visual layer (video/image/text/shape)')
                }
            }

            ToolButton {
                text: qsTr('+ Audio')
                implicitHeight: 24
                onClicked: root.addLayer(true)

                Shotcut.HoverTip {
                    text: qsTr('Add a new audio layer')
                }
            }

            Item {
                Layout.fillWidth: true
            }

            ToolButton {
                text: '−'
                implicitWidth: 24
                implicitHeight: 24
                onClicked: root.adjustZoom(1 / 1.4)
            }

            ToolButton {
                text: '+'
                implicitWidth: 24
                implicitHeight: 24
                onClicked: root.adjustZoom(1.4)
            }
        }
    }
}
