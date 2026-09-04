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

// One horizontal lane in the layer stack, holding the LayerBlock elements that
// belong to one underlying MLT track. Mirrors src/qml/views/timeline/Track.qml
// but skips the waveform/thumbnail-painting machinery -- LayerBlock renders a
// flat colored block instead.
Item {
    id: layerRow

    property alias model: clipModel.model
    property alias rootIndex: clipModel.rootIndex
    property bool isAudio: false
    property bool isLocked: false
    property int trackIndex: 0
    property int trackCount: 1
    property real rowHeight: 56
    // function(frame, duration, skipTrack, skipClip) -> snapped frame
    property var snapFrame: null
    readonly property alias clipCount: repeater.count

    signal blockClicked(int clipIndex, int modifiers)
    signal blockDoubleClicked(int clipIndex)
    signal layerHoverChanged(int targetTrack)
    // Where the element being dragged would land if dropped right now.
    signal dragPreviewChanged(int startFrame, int durationFrames, int targetTrack, color tint, int sourceStart, int sourceTrack)
    signal dragPreviewEnded

    // itemAt() is a method call, so it creates no binding dependency; if a
    // delegate is not built yet when this first runs, the width would stay
    // stale and the view would refuse to scroll past it. Bumping layoutEpoch
    // after the delegates settle forces a re-read, as Track.qml does.
    property int layoutEpoch: 0

    height: rowHeight
    width: {
        layoutEpoch;
        let end = 0;
        for (let i = 0; i < repeater.count; i++) {
            const c = repeater.itemAt(i);
            if (c)
                end = Math.max(end, c.clipPx + c.clipPxW);
        }
        return Math.max(end, 1);
    }

    // resizeTransition() grows a transition on both sides at once, so a frame of
    // applied resize is two frames of movement. Accumulate like the classic view
    // does instead of applying every drag frame twice over.
    property int _transitionAccum: 0

    function resizeTransitionBy(clipIndex, deltaFrames) {
        _transitionAccum += deltaFrames;
        const step = (_transitionAccum >= 2) ? 1 : (_transitionAccum <= -2) ? -1 : 0;
        if (step === 0)
            return;
        if (timeline.resizeTransition(layerRow.trackIndex, clipIndex, step))
            _transitionAccum -= step * 2;
        else
            _transitionAccum = 0;
    }

    function blockAt(index) {
        return repeater.itemAt(index);
    }

    function resolveTargetTrack(layerDelta) {
        if (layerDelta === 0)
            return layerRow.trackIndex;
        return Logic.clamp(layerRow.trackIndex + layerDelta, 0, layerRow.trackCount - 1);
    }

    // The delegate must live inside the DelegateModel: a Repeater bound to a
    // DelegateModel uses that model's own delegate and ignores its own (this is
    // how ../timeline/Track.qml is structured too).
    DelegateModel {
        id: clipModel

        LayerBlock {
            id: blockItem

            trackIndex: layerRow.trackIndex
            clipIndex: index
            rowHeight: layerRow.rowHeight
            isLocked: layerRow.isLocked
            snapFrame: layerRow.snapFrame
            isAudio: layerRow.isAudio || (typeof model.audio !== 'undefined' && model.audio)
            isBlank: typeof model.blank !== 'undefined' ? model.blank : false
            isTransition: typeof model.isTransition !== 'undefined' ? model.isTransition : false
            clipName: typeof model.name !== 'undefined' ? model.name : ''
            mltService: typeof model.mlt_service !== 'undefined' ? model.mlt_service : ''
            clipStart: typeof model.start !== 'undefined' ? model.start : 0
            clipDuration: typeof model.duration !== 'undefined' ? model.duration : 0
            selected: Logic.selectionContains(layerRow.trackIndex, index)

            onClicked: mouse => {
                layerRow.blockClicked(blockItem.clipIndex, mouse.modifiers);
            }
            onDoubleClicked: {
                layerRow.blockDoubleClicked(blockItem.clipIndex);
            }
            onLayerHoverDelta: delta => {
                layerRow.layerHoverChanged(delta === 0 ? -1 : layerRow.resolveTargetTrack(delta));
            }
            onDragPreview: (startFrame, layerDelta) => {
                layerRow.dragPreviewChanged(startFrame, blockItem.clipDuration, layerRow.resolveTargetTrack(layerDelta), blockItem.typeColor, blockItem.clipStart, layerRow.trackIndex);
            }
            onDragEnded: layerRow.dragPreviewEnded()
            onTrimInRequested: delta => {
                // delta is already "positive shrinks" (dragging the left edge
                // rightward shrinks the transition), matching resizeTransition's
                // own convention, so it is passed through unchanged.
                if (blockItem.isTransition) {
                    layerRow.resizeTransitionBy(blockItem.clipIndex, delta);
                    return;
                }
                timeline.trimClipIn(layerRow.trackIndex, blockItem.clipIndex, blockItem.clipIndex, delta, false, false);
            }
            onTrimOutRequested: delta => {
                if (blockItem.isTransition) {
                    layerRow.resizeTransitionBy(blockItem.clipIndex, delta);
                    return;
                }
                timeline.trimClipOut(layerRow.trackIndex, blockItem.clipIndex, delta, false, false);
            }
            onTrimCommitted: {
                layerRow._transitionAccum = 0;
                timeline.commitTrimCommand();
            }
            onMoveCommitted: (newStartFrame, layerDelta) => {
                const targetTrack = layerRow.resolveTargetTrack(layerDelta);
                timeline.moveClip(layerRow.trackIndex, targetTrack, blockItem.clipIndex, newStartFrame, false);
            }
        }
    }

    Repeater {
        id: repeater

        model: clipModel
        onCountChanged: Qt.callLater(() => layerRow.layoutEpoch++)
    }
}
