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

    color: activePalette.window
    focus: true

    SystemPalette {
        id: activePalette
    }

    Keys.onPressed: event => {
        if ((event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) && timeline.selection.length === 1) {
            const p = timeline.selection[0];
            timeline.lift(p.y, p.x);
            timeline.selection = [];
            event.accepted = true;
        }
    }

    function addLayer(isAudioLayer) {
        const idx = isAudioLayer ? timeline.addAudioTrack() : timeline.addVideoTrack();
        timeline.currentTrack = idx;
    }

    function adjustZoom(factor) {
        multitrack.scaleFactor = Math.max(0.002, Math.min(50, multitrack.scaleFactor * factor));
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
        height: root.height
        color: '#E0432B'
        visible: x >= root.headerWidth
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
                isAudio: typeof audio !== 'undefined' ? audio : false
                isLocked: typeof locked !== 'undefined' ? locked : false

                onBlockClicked: clipIndex => {
                    timeline.currentTrack = layerRowItem.trackIndex;
                    timeline.selection = [Qt.point(clipIndex, layerRowItem.trackIndex)];
                }
            }
        }

        Column {
            id: rowColumn

            Repeater {
                id: rowRepeater

                model: layerDelegateModel
            }
        }

        MouseArea {
            // Click empty space to clear selection.
            anchors.fill: parent
            z: -1
            onClicked: timeline.selection = []
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
        height: 8
        visible: root.newLayerZone !== ''
        color: '#2D9CC4'
        opacity: 0.8
        z: 61

        Label {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: root.newLayerZone === 'above' ? qsTr('New Layer') : qsTr('New Audio Layer')
            color: 'white'
            style: Text.Outline
            styleColor: '#00000080'
            font.pixelSize: 11
        }
    }

    DropArea {
        anchors.fill: tracksFlickable
        onEntered: drag => {
            if (drag.formats.indexOf('application/vnd.mlt+xml') >= 0 || drag.hasUrls)
                drag.acceptProposedAction();
        }
        onExited: root.newLayerZone = ''
        onPositionChanged: drag => {
            const edge = 14;
            if (drag.y < edge)
                root.newLayerZone = 'above';
            else if (drag.y > tracksFlickable.height - edge)
                root.newLayerZone = 'below';
            else
                root.newLayerZone = '';
            if (root.newLayerZone === '')
                timeline.currentTrack = Logic.clamp(Math.floor((drag.y + tracksFlickable.contentY) / root.rowHeight), 0, Math.max(0, layerRepeater.count - 1));
        }
        onDropped: drop => {
            const position = Math.max(0, Math.round((drop.x + tracksFlickable.contentX) / multitrack.scaleFactor));
            const xml = drop.formats.indexOf('application/vnd.mlt+xml') >= 0 ? drop.getDataAsString('application/vnd.mlt+xml') : drop.urls;
            if (root.newLayerZone !== '')
                timeline.handleDropNewTrack(root.newLayerZone === 'above', position, xml);
            else if (timeline.currentTrack >= 0)
                timeline.handleDrop(timeline.currentTrack, position, xml);
            root.newLayerZone = '';
            drop.acceptProposedAction();
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
