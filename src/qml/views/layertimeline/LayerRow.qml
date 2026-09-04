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
import "LayerTimeline.js" as Logic

// One horizontal lane in the layer stack, holding the LayerBlock elements
// that belong to one underlying MLT track. Mirrors
// src/qml/views/timeline/Track.qml but skips the waveform/thumbnail-painting
// machinery -- LayerBlock renders a flat colored block instead.
Item {
    id: layerRow

    property alias model: clipModel.model
    property alias rootIndex: clipModel.rootIndex
    property bool isAudio: false
    property bool isLocked: false
    property int trackIndex: 0
    property int trackCount: 1
    property real rowHeight: 56
    readonly property alias clipCount: repeater.count

    signal blockClicked(int clipIndex)

    height: rowHeight
    width: {
        let end = 0;
        for (let i = 0; i < repeater.count; i++) {
            const c = repeater.itemAt(i);
            if (c)
                end = Math.max(end, c.clipPx + c.clipPxW);
        }
        return Math.max(end, 1);
    }

    function resolveTargetTrack(fromTrack, layerDelta) {
        if (layerDelta === 0)
            return fromTrack;
        return Logic.clamp(fromTrack + layerDelta, 0, layerRow.trackCount - 1);
    }

    // The delegate must live inside the DelegateModel: a Repeater bound to a
    // DelegateModel uses that model's own delegate and ignores its own (this
    // is how ../timeline/Track.qml is structured too).
    DelegateModel {
        id: clipModel

        LayerBlock {
            id: blockItem

            trackIndex: layerRow.trackIndex
            clipIndex: index
            rowHeight: layerRow.rowHeight
            isLocked: layerRow.isLocked
            isAudio: layerRow.isAudio || (typeof model.audio !== 'undefined' && model.audio)
            isBlank: typeof model.blank !== 'undefined' ? model.blank : false
            isTransition: typeof model.isTransition !== 'undefined' ? model.isTransition : false
            clipName: typeof model.name !== 'undefined' ? model.name : ''
            mltService: typeof model.mlt_service !== 'undefined' ? model.mlt_service : ''
            clipStart: typeof model.start !== 'undefined' ? model.start : 0
            clipDuration: typeof model.duration !== 'undefined' ? model.duration : 0
            selected: Logic.selectionContains(layerRow.trackIndex, index)

            onClicked: mouse => {
                layerRow.blockClicked(blockItem.clipIndex);
            }
            onDoubleClicked: {
                const newPosition = blockItem.clipStart + blockItem.clipDuration;
                timeline.copy(layerRow.trackIndex, blockItem.clipIndex);
                timeline.insert(layerRow.trackIndex, newPosition);
            }
            onTrimInRequested: delta => {
                timeline.trimClipIn(layerRow.trackIndex, blockItem.clipIndex, blockItem.clipIndex, delta, false, false);
            }
            onTrimOutRequested: delta => {
                timeline.trimClipOut(layerRow.trackIndex, blockItem.clipIndex, delta, false, false);
            }
            onTrimCommitted: {
                timeline.commitTrimCommand();
            }
            onMoveCommitted: (deltaFrames, layerDelta) => {
                if (deltaFrames === 0 && layerDelta === 0)
                    return;
                const newPosition = Math.max(0, blockItem.clipStart + deltaFrames);
                const targetTrack = layerRow.resolveTargetTrack(layerRow.trackIndex, layerDelta);
                timeline.moveClip(layerRow.trackIndex, targetTrack, blockItem.clipIndex, newPosition, false);
            }
        }
    }

    Repeater {
        id: repeater

        model: clipModel
    }
}
