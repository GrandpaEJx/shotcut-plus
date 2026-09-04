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
import QtQuick.Controls
import QtQuick.Layouts
import Shotcut.Controls as Shotcut

// Minimal per-layer header: name, a type accent, and hide/lock/delete --
// deliberately much lighter than src/qml/views/timeline/TrackHead.qml since
// there is no separate audio-gain/meter UI in the layer view.
Rectangle {
    id: head

    property int trackIndex: 0
    property string trackName: ''
    property bool isAudio: false
    property bool isHidden: false
    property bool isLocked: false
    property bool isCurrent: false
    readonly property color accent: isAudio ? '#5A9B72' : '#2D9CC4'

    signal clicked
    signal renamed(string name)
    signal toggleHidden
    signal toggleLocked
    signal removeRequested
    // Move this layer's stacking order up (-1) or down (+1) by one row.
    signal reorder(int direction)

    width: parent ? parent.width : 160
    color: isCurrent ? Qt.rgba(accent.r, accent.g, accent.b, 0.16) : (trackIndex % 2 ? activePalette.alternateBase : activePalette.base)

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: head.isCurrent ? 3 : 0
        color: head.accent
        visible: width > 0
    }

    MouseArea {
        anchors.fill: parent
        anchors.rightMargin: reorderColumn.width + 4
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: head.clicked()
    }

    // Up/down arrows re-stack this layer above/below its neighbor -- simpler
    // and safer than a free vertical drag-to-reorder gesture.
    Column {
        id: reorderColumn

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: 2
        spacing: 0

        ToolButton {
            text: '▴'
            implicitWidth: 14
            implicitHeight: 12
            padding: 0
            focusPolicy: Qt.NoFocus
            font.pixelSize: 8
            onClicked: head.reorder(-1)

            Shotcut.HoverTip {
                text: qsTr('Move layer up')
                cursorShape: Qt.PointingHandCursor
            }
        }

        ToolButton {
            text: '▾'
            implicitWidth: 14
            implicitHeight: 12
            padding: 0
            focusPolicy: Qt.NoFocus
            font.pixelSize: 8
            onClicked: head.reorder(1)

            Shotcut.HoverTip {
                text: qsTr('Move layer down')
                cursorShape: Qt.PointingHandCursor
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: reorderColumn.width + 6
        spacing: 3

        Text {
            text: head.isAudio ? '♪' : '▶'
            color: head.accent
            font.pixelSize: 12
            font.bold: true
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 18

            Label {
                anchors.fill: parent
                visible: !nameEdit.visible
                text: head.trackName
                color: activePalette.windowText
                elide: Qt.ElideRight
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: 12
            }

            TextField {
                id: nameEdit

                anchors.fill: parent
                visible: focus
                text: head.trackName
                font.pixelSize: 12
                padding: 0
                selectByMouse: true
                onEditingFinished: {
                    head.renamed(text);
                    focus = false;
                }
                Keys.onEscapePressed: {
                    text = head.trackName;
                    focus = false;
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: !nameEdit.visible
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: head.clicked()
                onDoubleClicked: {
                    nameEdit.text = head.trackName;
                    nameEdit.forceActiveFocus();
                    nameEdit.selectAll();
                }

                Shotcut.HoverTip {
                    text: qsTr('Double-click to rename this layer')
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }

        ToolButton {
            icon.name: head.isHidden ? 'layer-visible-off' : 'layer-visible-on'
            icon.source: head.isHidden ? 'qrc:///icons/oxygen/32x32/actions/layer-visible-off.png' : 'qrc:///icons/oxygen/32x32/actions/layer-visible-on.png'
            icon.width: 13
            icon.height: 13
            implicitWidth: 18
            implicitHeight: 18
            padding: 0
            visible: !head.isAudio
            focusPolicy: Qt.NoFocus
            onClicked: head.toggleHidden()

            Shotcut.HoverTip {
                text: qsTr('Show/Hide')
                cursorShape: Qt.PointingHandCursor
            }
        }

        ToolButton {
            icon.name: head.isLocked ? 'object-locked' : 'object-unlocked'
            icon.source: head.isLocked ? 'qrc:///icons/oxygen/32x32/status/object-locked.png' : 'qrc:///icons/oxygen/32x32/status/object-unlocked.png'
            icon.width: 13
            icon.height: 13
            implicitWidth: 18
            implicitHeight: 18
            padding: 0
            focusPolicy: Qt.NoFocus
            onClicked: head.toggleLocked()

            Shotcut.HoverTip {
                text: head.isLocked ? qsTr('Unlock layer') : qsTr('Lock layer')
                cursorShape: Qt.PointingHandCursor
            }
        }

        ToolButton {
            icon.name: 'edit-delete'
            icon.source: 'qrc:///icons/oxygen/32x32/actions/edit-delete.png'
            icon.width: 13
            icon.height: 13
            implicitWidth: 18
            implicitHeight: 18
            padding: 0
            focusPolicy: Qt.NoFocus
            onClicked: head.removeRequested()

            Shotcut.HoverTip {
                text: qsTr('Delete layer')
                cursorShape: Qt.PointingHandCursor
            }
        }
    }
}
