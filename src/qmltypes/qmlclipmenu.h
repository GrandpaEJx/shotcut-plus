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

#ifndef QMLCLIPMENU_H
#define QMLCLIPMENU_H

#include <QObject>

class TimelineDock;

// A self-contained, per-element right-click context menu for a single clip,
// exposed to QML so each LayerBlock instance can own one bound to its own
// (trackIndex, clipIndex) -- mirrors QmlMarkerMenu, which does the same for
// markers, rather than the classic timeline's single shared m_clipMenu that
// only ever acts on the current selection().
class QmlClipMenu : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QObject *target READ target WRITE setTarget NOTIFY targetChanged)
    Q_PROPERTY(int trackIndex READ trackIndex WRITE setTrackIndex NOTIFY trackIndexChanged)
    Q_PROPERTY(int clipIndex READ clipIndex WRITE setClipIndex NOTIFY clipIndexChanged)

public:
    explicit QmlClipMenu(QObject *parent = 0);
    QObject *target();
    void setTarget(QObject *timeline);
    int trackIndex();
    void setTrackIndex(int trackIndex);
    int clipIndex();
    void setClipIndex(int clipIndex);

signals:
    void targetChanged();
    void trackIndexChanged();
    void clipIndexChanged();

public slots:
    void popup();

private:
    TimelineDock *m_timeline;
    int m_trackIndex;
    int m_clipIndex;
};

#endif // QMLCLIPMENU_H
