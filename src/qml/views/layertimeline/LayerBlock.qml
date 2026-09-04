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
// that can be dragged to reposition, dragged at its edges to trim, and
// double-clicked to duplicate. Mirrors src/qml/views/timeline/Clip.qml's
// role bindings but with much simpler, flatter visuals.
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
    readonly property real clipPx: clipStart * multitrack.scaleFactor
    readonly property real clipPxW: Math.max(6, clipDuration * multitrack.scaleFactor)

    // Type classification purely for color/badge -- cosmetic only, does not
    // affect the underlying MLT producer.
    readonly property string elementType: {
        if (isAudio)
            return 'audio';
        if (mltService.indexOf('text') >= 0 || mltService === 'kdenlivetitle')
            return 'text';
        if (mltService === 'color' || mltService === 'qtblend')
            return 'shape';
        if (mltService === 'pixbuf' || mltService === 'qimage')
            return 'image';
        return 'video';
    }
    readonly property color typeColor: {
        if (elementType === 'audio')
            return '#5A9B72';
        if (elementType === 'text')
            return '#E2914B';
        if (elementType === 'shape')
            return '#8F7FE0';
        if (elementType === 'image')
            return '#C97ABF';
        return '#2D9CC4';
    }
    readonly property string typeGlyph: {
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

    // (deltaFrames, layerDelta): layerDelta is how many rows above(-)/below(+)
    // the pointer has moved, resolved to a target track by the parent LayerRow.
    signal clicked(var mouse)
    signal doubleClicked
    signal layerHoverDelta(int delta)
    signal moveCommitted(int deltaFrames, int layerDelta)
    signal trimInRequested(int deltaFrames)
    signal trimOutRequested(int deltaFrames)
    signal trimCommitted

    width: clipPxW
    height: rowHeight - 10
    y: 5
    radius: 8
    visible: !isBlank
    color: typeColor
    opacity: dragArea.drag.active ? 0.85 : 1
    border.width: selected ? 2 : 1
    border.color: selected ? '#FFFFFF' : Qt.darker(typeColor, 1.4)
    clip: true
    z: dragArea.drag.active ? 100 : 1

    // Only x is a live Qt Quick drag target (like Clip.qml's XAxis-only
    // drag); the block never actually leaves its own row's coordinate space,
    // so no reparenting/model-timing races are possible. Moving to a
    // different layer is resolved from the pointer's y at release time (see
    // dragArea below) and committed as a single moveClip() call.
    Binding on x {
        value: block.clipPx
        when: !dragArea.drag.active
    }

    // Left edge trim handle
    MouseArea {
        id: trimInArea

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 8
        cursorShape: Qt.SizeHorCursor
        enabled: !isBlank && !isTransition && !block.isLocked
        property real pressX: 0
        property int lastFrameDelta: 0
        onPressed: mouse => {
            pressX = mouse.x;
            lastFrameDelta = 0;
        }
        onPositionChanged: mouse => {
            if (!pressed)
                return;
            const totalFrameDelta = Math.round((mouse.x - pressX) / multitrack.scaleFactor);
            const incremental = totalFrameDelta - lastFrameDelta;
            if (incremental !== 0) {
                block.trimInRequested(incremental);
                lastFrameDelta = totalFrameDelta;
            }
        }
        onReleased: block.trimCommitted()
    }

    // Right edge trim handle
    MouseArea {
        id: trimOutArea

        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 8
        cursorShape: Qt.SizeHorCursor
        enabled: !isBlank && !isTransition && !block.isLocked
        property real pressX: 0
        property int lastFrameDelta: 0
        onPressed: mouse => {
            pressX = mouse.x;
            lastFrameDelta = 0;
        }
        onPositionChanged: mouse => {
            if (!pressed)
                return;
            const totalFrameDelta = Math.round((mouse.x - pressX) / multitrack.scaleFactor);
            const incremental = totalFrameDelta - lastFrameDelta;
            if (incremental !== 0) {
                block.trimOutRequested(incremental);
                lastFrameDelta = totalFrameDelta;
            }
        }
        onReleased: block.trimCommitted()
    }

    Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 5
        clip: true
        width: parent.width - 20

        Text {
            text: block.typeGlyph
            color: 'white'
            font.pixelSize: 11
            font.bold: true
        }

        Text {
            text: block.clipName
            color: 'white'
            font.pixelSize: 11
            elide: Text.ElideRight
            width: parent.width - 16
        }
    }

    // Body drag: reposition in time (x, via the real Quick drag target) and,
    // by how far the pointer has strayed above/below the block vertically,
    // offer to move it onto another layer -- resolved once, on release.
    MouseArea {
        id: dragArea

        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        enabled: !isBlank && !isTransition && !block.isLocked
        drag.target: block
        drag.axis: Drag.XAxis
        drag.minimumX: -100000
        drag.maximumX: 100000
        property real pressX: 0
        property real pressGlobalY: 0
        onPressed: mouse => {
            pressX = block.x;
            pressGlobalY = mapToItem(null, mouse.x, mouse.y).y;
            block.clicked(mouse);
        }
        onDoubleClicked: block.doubleClicked()
        onPositionChanged: mouse => {
            if (!pressed)
                return;
            const globalY = mapToItem(null, mouse.x, mouse.y).y;
            block.layerHoverDelta(Math.round((globalY - pressGlobalY) / block.rowHeight));
        }
        onReleased: mouse => {
            const deltaFrames = Math.round((block.x - pressX) / multitrack.scaleFactor);
            const globalY = mapToItem(null, mouse.x, mouse.y).y;
            const layerDelta = Math.round((globalY - pressGlobalY) / block.rowHeight);
            block.moveCommitted(deltaFrames, layerDelta);
        }
    }

    Shotcut.HoverTip {
        text: block.clipName
    }
}
