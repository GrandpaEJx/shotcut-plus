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
import QtQuick
import Shotcut.Controls as Shotcut

// One design-oriented "element" on a layer: a rounded, colored, labeled block
// that can be dragged to reposition and dragged at its edges to trim. Mirrors
// src/qml/views/timeline/Clip.qml's role bindings but with much simpler, flatter
// visuals.
Rectangle {
    id: block

    property int trackIndex: 0
    property int clipIndex: 0
    property string clipName: ''
    property string mltService: ''
    property bool isAudio: false
    property bool isBlank: false
    property bool isTransition: false
    property int clipStart: 0
    property int clipDuration: 0
    property bool selected: false
    property bool isLocked: false
    property real rowHeight: 56
    // Optional function(frame, duration, skipTrack, skipClip) -> snapped frame,
    // supplied by LayerTimeline. Null disables snapping.
    property var snapFrame: null
    readonly property real clipPx: clipStart * multitrack.scaleFactor
    readonly property real clipPxW: Math.max(6, clipDuration * multitrack.scaleFactor)
    readonly property bool dragging: dragArea.drag.active

    // Type classification purely for color/badge -- cosmetic only, does not
    // affect the underlying MLT producer.
    readonly property string elementType: {
        if (isTransition)
            return 'transition';
        if (isAudio)
            return 'audio';
        if (mltService.indexOf('text') >= 0 || mltService === 'kdenlivetitle')
            return 'text';
        if (mltService === 'color')
            return 'shape';
        if (mltService === 'pixbuf' || mltService === 'qimage')
            return 'image';
        return 'video';
    }
    readonly property color typeColor: {
        if (elementType === 'transition')
            return '#8F7FE0';
        if (elementType === 'audio')
            return '#5A9B72';
        if (elementType === 'text')
            return '#E2914B';
        if (elementType === 'shape')
            return '#F5A524';
        if (elementType === 'image')
            return '#C97ABF';
        return '#2D9CC4';
    }
    readonly property string typeGlyph: {
        if (elementType === 'transition')
            return '⇄';
        if (elementType === 'audio')
            return '♪';
        if (elementType === 'text')
            return 'T';
        if (elementType === 'shape')
            return '▢';
        if (elementType === 'image')
            return '▣';
        return '▶';
    }
    readonly property string displayName: (isTransition && clipName === '') ? qsTr('Transition') : clipName

    // layerDelta is how many rows above(-)/below(+) the pointer has moved;
    // the parent LayerRow resolves it to a target track.
    signal clicked(var mouse)
    signal doubleClicked
    signal layerHoverDelta(int delta)
    // Live landing preview while dragging: where it would go if released now.
    signal dragPreview(int startFrame, int layerDelta)
    signal dragEnded
    signal moveCommitted(int newStartFrame, int layerDelta)
    signal trimInRequested(int deltaFrames)
    signal trimOutRequested(int deltaFrames)
    signal trimCommitted

    width: clipPxW
    height: rowHeight - 10
    radius: 8
    visible: !isBlank
    color: dragArea.containsMouse && !dragArea.drag.active ? Qt.lighter(typeColor, 1.12) : typeColor
    // Locked layers read as dimmed, matching that their blocks do not respond.
    // While dragging, the block is the thing under your cursor and the ghost
    // outline is the real destination, so the block fades back.
    opacity: block.isLocked ? 0.5 : (dragArea.drag.active ? 0.45 : 1)
    border.width: selected ? 2 : 1
    border.color: selected ? '#FFFFFF' : Qt.darker(typeColor, 1.4)
    clip: true
    z: dragArea.drag.active ? 100 : 1

    // Only x is a live Qt Quick drag target (like Clip.qml's XAxis-only drag);
    // the block never leaves its own row's coordinate space, so no reparenting
    // or model-timing races are possible. Moving to a different layer is
    // resolved from the pointer's y at release and committed as one moveClip().
    Binding on x {
        value: block.clipPx
        when: !dragArea.drag.active
    }

    // y follows the cursor only while dragging, then snaps back to its lane.
    // The block floats over the neighbouring rows (nothing between here and the
    // Flickable clips), so dragging up/down is visible instead of invisible.
    Binding on y {
        value: 5
        when: !dragArea.drag.active
    }

    Behavior on color {
        ColorAnimation {
            duration: 90
        }
    }

    // Left edge trim handle. Deltas are measured in *scene* coordinates and the
    // baseline is reset after each applied step: the handle itself moves as the
    // model applies the trim, so a MouseArea-local delta would double-count.
    MouseArea {
        id: trimInArea

        // Above dragArea (declared later, below) so this handle's cursor and
        // clicks always win at the very edge, the same guarantee Clip.qml gets
        // by nesting its trim handles inside overlay Rectangles on top.
        z: 2
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        // Wider than dragArea's 8px exclusion margin on purpose: the extra
        // overlap is safe now that z puts this handle on top, and it makes the
        // resize cursor much easier to land than an exact 8px sliver.
        width: 12
        hoverEnabled: true
        cursorShape: Qt.SizeHorCursor
        // Transitions are trimmable (that resizes the crossfade) but not movable.
        enabled: !isBlank && !block.isLocked
        property real lastSceneX: 0
        property bool trimmed: false
        onPressed: mouse => {
            lastSceneX = mapToItem(null, mouse.x, mouse.y).x;
            trimmed = false;
        }
        onPositionChanged: mouse => {
            if (!pressed)
                return;
            const sceneX = mapToItem(null, mouse.x, mouse.y).x;
            const delta = Math.round((sceneX - lastSceneX) / multitrack.scaleFactor);
            if (delta !== 0) {
                block.trimInRequested(delta);
                lastSceneX = sceneX;
                trimmed = true;
            }
        }
        onReleased: {
            if (trimmed)
                block.trimCommitted();
        }
    }

    // Grip shown once selected (or on direct hover) so it is obvious the edges
    // can be grabbed to expand/collapse the element's duration.
    Rectangle {
        anchors.left: parent.left
        anchors.leftMargin: 3
        anchors.verticalCenter: parent.verticalCenter
        width: 4
        height: parent.height * 0.55
        radius: 2
        visible: trimInArea.enabled && (block.selected || trimInArea.containsMouse)
        color: trimInArea.containsMouse ? '#FFFFFF' : Qt.rgba(1, 1, 1, 0.65)
        opacity: visible ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 90
            }
        }
    }

    // Right edge trim handle.
    MouseArea {
        id: trimOutArea

        // Above dragArea for the same reason as trimInArea above.
        z: 2
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        // See trimInArea above: wider than dragArea's margin on purpose.
        width: 12
        hoverEnabled: true
        cursorShape: Qt.SizeHorCursor
        // Transitions are trimmable (that resizes the crossfade) but not movable.
        enabled: !isBlank && !block.isLocked
        property real lastSceneX: 0
        property bool trimmed: false
        onPressed: mouse => {
            lastSceneX = mapToItem(null, mouse.x, mouse.y).x;
            trimmed = false;
        }
        onPositionChanged: mouse => {
            if (!pressed)
                return;
            const sceneX = mapToItem(null, mouse.x, mouse.y).x;
            // Trim/resize deltas are "positive shrinks" by convention (see
            // trimClipOut/resizeTransition), so dragging this edge to the
            // right (growing the block) must yield a negative delta.
            const delta = Math.round((lastSceneX - sceneX) / multitrack.scaleFactor);
            if (delta !== 0) {
                block.trimOutRequested(delta);
                lastSceneX = sceneX;
                trimmed = true;
            }
        }
        onReleased: {
            if (trimmed)
                block.trimCommitted();
        }
    }

    Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: 3
        anchors.verticalCenter: parent.verticalCenter
        width: 4
        height: parent.height * 0.55
        radius: 2
        visible: trimOutArea.enabled && (block.selected || trimOutArea.containsMouse)
        color: trimOutArea.containsMouse ? '#FFFFFF' : Qt.rgba(1, 1, 1, 0.65)
        opacity: visible ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 90
            }
        }
    }

    // Transitions get Shotcut's own crossfade drawing, the same shape the
    // classic timeline uses, so they never read as an ordinary element.
    // TimelineTransition is a QQuickPaintedItem (its own texture), so like
    // Clip.qml it is loaded only for actual transitions -- instantiating one
    // per block and merely hiding it costs a texture for every clip.
    Loader {
        anchors.fill: parent
        anchors.margins: block.border.width
        active: block.isTransition
        sourceComponent: transitionComponent
    }

    Component {
        id: transitionComponent

        Shotcut.TimelineTransition {
            colorA: block.typeColor
            colorB: block.selected ? Qt.darker(block.typeColor) : Qt.lighter(block.typeColor)
        }
    }

    Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 5
        clip: true
        visible: !block.isTransition || block.width > 70
        width: parent.width - 20

        Text {
            text: block.typeGlyph
            color: 'white'
            font.pixelSize: 11
            font.bold: true
        }

        Text {
            text: block.displayName
            color: 'white'
            font.pixelSize: 11
            elide: Text.ElideRight
            width: parent.width - 16
        }
    }

    // Body drag: x is a real Quick drag target; how far the pointer strays
    // vertically decides which layer it lands on, resolved once on release.
    MouseArea {
        id: dragArea

        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        hoverEnabled: true
        // Enabled even for transitions and locked layers: those cannot be
        // dragged, but they must still be clickable to select them and open
        // their properties. Only the drag target is withheld.
        enabled: !isBlank
        readonly property bool movable: !block.isTransition && !block.isLocked
        cursorShape: !movable ? Qt.PointingHandCursor : (drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor)
        drag.target: movable ? block : null
        drag.axis: Drag.XAndYAxis
        drag.minimumX: 0
        drag.maximumX: 1000000
        drag.minimumY: -20000
        drag.maximumY: 20000
        // Require a real drag before committing, so a plain click cannot nudge
        // the element by a frame or two at high zoom.
        property bool dragActivated: false
        property real pressGlobalY: 0
        onPressed: mouse => {
            pressGlobalY = mapToItem(null, mouse.x, mouse.y).y;
            dragActivated = false;
            block.clicked(mouse);
        }
        onDoubleClicked: block.doubleClicked()
        onPositionChanged: mouse => {
            if (!pressed || !movable)
                return;
            if (drag.active) {
                dragActivated = true;
                if (block.snapFrame) {
                    const raw = block.x / multitrack.scaleFactor;
                    const snapped = block.snapFrame(raw, block.clipDuration, block.trackIndex, block.clipIndex);
                    block.x = snapped * multitrack.scaleFactor;
                }
            }
            const globalY = mapToItem(null, mouse.x, mouse.y).y;
            const layerDelta = Math.round((globalY - pressGlobalY) / block.rowHeight);
            block.layerHoverDelta(layerDelta);
            if (dragActivated)
                block.dragPreview(Math.max(0, Math.round(block.x / multitrack.scaleFactor)), layerDelta);
        }
        onReleased: mouse => {
            const globalY = mapToItem(null, mouse.x, mouse.y).y;
            const layerDelta = Math.round((globalY - pressGlobalY) / block.rowHeight);
            const newStart = Math.max(0, Math.round(block.x / multitrack.scaleFactor));
            const wasDragged = dragActivated;
            dragActivated = false;
            block.layerHoverDelta(0);
            block.dragEnded();
            if (!wasDragged)
                return;
            if (newStart === block.clipStart && layerDelta === 0)
                return;
            block.moveCommitted(newStart, layerDelta);
        }
        onCanceled: {
            dragActivated = false;
            block.layerHoverDelta(0);
            block.dragEnded();
        }
    }

    Shotcut.HoverTip {
        text: block.displayName
    }
}
