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

#include "qmlclipmenu.h"

#include "actions.h"
#include "docks/timelinedock.h"
#include "models/multitrackmodel.h"
#include "qmltypes/colordialog.h"

#include <QAction>
#include <QIcon>
#include <QMenu>
#include <QPixmap>

#include <memory>
#include <vector>

QmlClipMenu::QmlClipMenu(QObject *parent)
    : QObject(parent)
    , m_timeline(nullptr)
    , m_trackIndex(-1)
    , m_clipIndex(-1)
{}

QObject *QmlClipMenu::target()
{
    return m_timeline;
}

void QmlClipMenu::setTarget(QObject *target)
{
    m_timeline = dynamic_cast<TimelineDock *>(target);
}

int QmlClipMenu::trackIndex()
{
    return m_trackIndex;
}

void QmlClipMenu::setTrackIndex(int trackIndex)
{
    m_trackIndex = trackIndex;
}

int QmlClipMenu::clipIndex()
{
    return m_clipIndex;
}

void QmlClipMenu::setClipIndex(int clipIndex)
{
    m_clipIndex = clipIndex;
}

namespace {
// A small solid-color square, used both as a swatch icon and as the "current
// color" hint next to Custom Color... -- simpler than the marker menu's
// QToolButton swatches since these do not need per-swatch hover styling.
QIcon swatchIcon(const QColor &color)
{
    QPixmap pixmap(16, 16);
    pixmap.fill(color);
    return QIcon(pixmap);
}
} // namespace

void QmlClipMenu::popup()
{
    if (!m_timeline || m_trackIndex < 0 || m_clipIndex < 0)
        return;

    MultitrackModel *model = m_timeline->model();
    QModelIndex clipModelIndex = model->index(m_clipIndex, 0, model->index(m_trackIndex));
    QString currentColor = model->data(clipModelIndex, MultitrackModel::ClipColorRole).toString();
    bool isLocked = m_timeline->isClipLocked(m_trackIndex, m_clipIndex);

    QMenu menu;

    // Reusing the same global QActions the toolbar/m_clipMenu use keeps
    // shortcuts, icons, and selection-based enablement consistent for free.
    menu.addAction(Actions["timelineCutAction"]);
    menu.addAction(Actions["timelineCopyAction"]);

    QAction duplicateAction(tr("Duplicate"));
    duplicateAction.setIcon(
        QIcon::fromTheme("edit-copy", QIcon(":/icons/oxygen/32x32/actions/edit-copy.png")));
    connect(&duplicateAction, &QAction::triggered, this, [&]() {
        auto info = model->getClipInfo(m_trackIndex, m_clipIndex);
        if (!info)
            return;
        m_timeline->copy(m_trackIndex, m_clipIndex);
        m_timeline->overwrite(m_trackIndex, info->start + info->frame_count, QString(), false);
    });
    menu.addAction(&duplicateAction);

    menu.addSeparator();
    menu.addAction(Actions["timelineLiftAction"]);
    menu.addAction(Actions["timelineDeleteAction"]);

    menu.addSeparator();

    QAction lockAction(isLocked ? tr("Unlock") : tr("Lock"));
    lockAction.setCheckable(true);
    lockAction.setChecked(isLocked);
    lockAction.setIcon(QIcon::fromTheme(isLocked ? "object-locked" : "object-unlocked",
                                       QIcon(isLocked
                                                 ? ":/icons/oxygen/32x32/status/object-locked.png"
                                                 : ":/icons/oxygen/32x32/status/object-unlocked.png")));
    connect(&lockAction, &QAction::triggered, this, [&]() {
        m_timeline->setClipLock(m_trackIndex, m_clipIndex, !isLocked);
    });
    menu.addAction(&lockAction);

    QMenu *colorMenu = menu.addMenu(tr("Color"));

    QAction noColorAction(tr("No Color"));
    noColorAction.setCheckable(true);
    noColorAction.setChecked(currentColor.isEmpty());
    connect(&noColorAction, &QAction::triggered, this, [&]() {
        m_timeline->setClipColor(m_trackIndex, m_clipIndex, QString());
    });
    colorMenu->addAction(&noColorAction);
    colorMenu->addSeparator();

    static const char *kSwatches[] =
        {"#E74C3C", "#F39C12", "#F1C40F", "#2ECC71", "#3498DB", "#9B59B6"};
    std::vector<std::unique_ptr<QAction>> swatchActions;
    for (const char *hex : kSwatches) {
        QColor swatch(hex);
        auto swatchAction = std::make_unique<QAction>(swatchIcon(swatch), QString());
        swatchAction->setCheckable(true);
        swatchAction->setChecked(currentColor.compare(hex, Qt::CaseInsensitive) == 0);
        QString colorName = swatch.name();
        connect(swatchAction.get(), &QAction::triggered, this, [this, colorName]() {
            m_timeline->setClipColor(m_trackIndex, m_clipIndex, colorName);
        });
        colorMenu->addAction(swatchAction.get());
        swatchActions.push_back(std::move(swatchAction));
    }

    colorMenu->addSeparator();
    QAction customColorAction(tr("Custom Color..."));
    connect(&customColorAction, &QAction::triggered, this, [&]() {
        QColor initial = currentColor.isEmpty() ? QColor(Qt::white) : QColor(currentColor);
        QColor newColor = ColorDialog::getColor(initial, nullptr, QString(), false);
        if (newColor.isValid())
            m_timeline->setClipColor(m_trackIndex, m_clipIndex, newColor.name());
    });
    colorMenu->addAction(&customColorAction);

    menu.addSeparator();
    menu.addAction(Actions["timelinePropertiesAction"]);

    menu.exec(QCursor::pos());
}
