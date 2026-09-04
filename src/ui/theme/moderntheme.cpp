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

#include "moderntheme.h"

#include <QColor>
#include <Qt>

namespace {

// Token values. One accent, a numbered-in-spirit neutral ramp, and flat
// surfaces - Spectrum's structure, Apple's restraint (no chrome borders,
// separation by elevation), CapCut's radii, Carbon's "one accent" discipline.
struct Tokens
{
    QColor window;
    QColor base;
    QColor surface; // AlternateBase: raised/alternate rows, tab strips
    QColor border;
    QColor text;
    QColor muted;
    QColor accent;
    QColor onAccent;
};

const Tokens &darkTokens()
{
    static const Tokens t{
        QColor("#16181A"), // window
        QColor("#1B1E21"), // base
        QColor("#212528"), // surface
        QColor("#2B3033"), // border
        QColor("#ECEEEF"), // text
        QColor("#8D979B"), // muted
        QColor("#2D9CC4"), // accent (lifted from Shotcut's own #175C76)
        QColor("#FFFFFF")  // onAccent
    };
    return t;
}

const Tokens &lightTokens()
{
    static const Tokens t{
        QColor("#F1F3F4"), // window
        QColor("#FFFFFF"), // base
        QColor("#E7EBEC"), // surface
        QColor("#D3D9DB"), // border
        QColor("#14181A"), // text
        QColor("#5B6669"), // muted
        QColor("#0E7292"), // accent
        QColor("#FFFFFF")  // onAccent
    };
    return t;
}

} // namespace

namespace ModernTheme {

QPalette darkPalette()
{
    const Tokens &t = darkTokens();
    QPalette palette;
    palette.setColor(QPalette::Window, t.window);
    palette.setColor(QPalette::WindowText, t.text);
    palette.setColor(QPalette::Base, t.base);
    palette.setColor(QPalette::AlternateBase, t.surface);
    palette.setColor(QPalette::Highlight, t.accent);
    palette.setColor(QPalette::HighlightedText, t.onAccent);
    palette.setColor(QPalette::ToolTipBase, t.surface);
    palette.setColor(QPalette::ToolTipText, t.text);
    palette.setColor(QPalette::Text, t.text);
    palette.setColor(QPalette::BrightText, Qt::red);
    palette.setColor(QPalette::Button, t.window);
    palette.setColor(QPalette::ButtonText, t.text);
    palette.setColor(QPalette::Link, t.accent.lighter(120));
    palette.setColor(QPalette::LinkVisited, t.accent);
    palette.setColor(QPalette::PlaceholderText, t.muted);
    palette.setColor(QPalette::Disabled, QPalette::Base, t.base.darker(110));
    palette.setColor(QPalette::Disabled, QPalette::Text, t.muted);
    palette.setColor(QPalette::Disabled, QPalette::ButtonText, t.muted);
    palette.setColor(QPalette::Disabled, QPalette::Light, Qt::transparent);
    return palette;
}

QPalette lightPalette()
{
    const Tokens &t = lightTokens();
    QPalette palette;
    palette.setColor(QPalette::Window, t.window);
    palette.setColor(QPalette::WindowText, t.text);
    palette.setColor(QPalette::Base, t.base);
    palette.setColor(QPalette::AlternateBase, t.surface);
    palette.setColor(QPalette::Highlight, t.accent);
    palette.setColor(QPalette::HighlightedText, t.onAccent);
    palette.setColor(QPalette::ToolTipBase, t.surface);
    palette.setColor(QPalette::ToolTipText, t.text);
    palette.setColor(QPalette::Text, t.text);
    palette.setColor(QPalette::BrightText, QColor("#C0392B"));
    palette.setColor(QPalette::Button, t.window);
    palette.setColor(QPalette::ButtonText, t.text);
    palette.setColor(QPalette::Link, t.accent);
    palette.setColor(QPalette::LinkVisited, t.accent.darker(115));
    palette.setColor(QPalette::PlaceholderText, t.muted);
    palette.setColor(QPalette::Disabled, QPalette::Text, t.muted);
    palette.setColor(QPalette::Disabled, QPalette::ButtonText, t.muted);
    palette.setColor(QPalette::Disabled, QPalette::Light, Qt::transparent);
    return palette;
}

QString styleSheet(bool dark)
{
    const Tokens &t = dark ? darkTokens() : lightTokens();
    const QString window = t.window.name();
    const QString surface = t.surface.name();
    const QString surfaceHover = dark ? t.surface.lighter(112).name() : t.surface.darker(104).name();
    const QString border = t.border.name();
    const QString text = t.text.name();
    const QString muted = t.muted.name();
    const QString accent = t.accent.name();
    const QString onAccent = t.onAccent.name();

    return QStringLiteral(
               // Flat tab strips: one hairline instead of a beveled box,
               // radius on the leading corners only, accent underline on
               // the active tab rather than a border ring.
               "QTabBar::tab {"
               "  background: %1; color: %5; padding: 6px 12px;"
               "  border: none; margin-right: 1px; }"
               "QTabBar::tab:top {"
               "  border-top-left-radius: 6px; border-top-right-radius: 6px; }"
               "QTabBar::tab:bottom {"
               "  border-bottom-left-radius: 6px; border-bottom-right-radius: 6px; }"
               "QTabBar::tab:selected {"
               "  background: %2; color: %6; }"
               "QTabBar::tab:top:selected { border-top: 2px solid %7; padding-top: 4px; }"
               "QTabBar::tab:bottom:selected { border-bottom: 2px solid %7; padding-bottom: 4px; }"
               "QTabBar::tab:hover:!selected { background: %3; }"
               "QTabBar::tab:disabled { color: %5; }"
               // Tooltips: flat surface, no heavy border.
               "QToolTip {"
               "  background: %2; color: %6; border: 1px solid %4;"
               "  border-radius: 5px; padding: 4px 8px; }"
               // Scroll bars: thin, flat, accent-on-hover - CapCut-style
               // minimal chrome rather than a 3D groove.
               "QScrollBar:vertical { background: transparent; width: 12px; margin: 0; }"
               "QScrollBar::handle:vertical {"
               "  background: %4; min-height: 24px; border-radius: 5px; margin: 2px; }"
               "QScrollBar::handle:vertical:hover { background: %7; }"
               "QScrollBar:horizontal { background: transparent; height: 12px; margin: 0; }"
               "QScrollBar::handle:horizontal {"
               "  background: %4; min-width: 24px; border-radius: 5px; margin: 2px; }"
               "QScrollBar::handle:horizontal:hover { background: %7; }"
               "QScrollBar::add-line, QScrollBar::sub-line { width: 0; height: 0; border: none; }"
               "QScrollBar::add-page, QScrollBar::sub-page { background: none; }"
               // Buttons: flat, radius 6px, accent border on hover/focus
               // instead of a sunken bevel.
               "QPushButton, QToolButton {"
               "  border: 1px solid %4; border-radius: 6px;"
               "  background: %2; color: %6; padding: 4px 10px; }"
               "QPushButton:hover, QToolButton:hover { border-color: %7; }"
               "QPushButton:pressed, QToolButton:pressed { background: %3; }"
               "QPushButton:default { border-color: %7; }"
               // Inputs: flat with an accent focus ring, Apple-style.
               "QLineEdit, QComboBox, QSpinBox, QDoubleSpinBox, QAbstractSpinBox {"
               "  border: 1px solid %4; border-radius: 6px; padding: 2px 6px; background: %8; }"
               "QLineEdit:focus, QComboBox:focus, QAbstractSpinBox:focus { border-color: %7; }"
               // Menus and docks: separation by elevation, minimal rules.
               "QMenu { background: %2; border: 1px solid %4; border-radius: 8px; padding: 4px; }"
               "QMenu::item { padding: 5px 22px; border-radius: 5px; }"
               "QMenu::item:selected { background: %7; color: %9; }"
               "QDockWidget::title { background: %1; padding: 5px 8px; }")
        .arg(window,      // %1
             surface,      // %2
             surfaceHover, // %3
             border,       // %4
             muted,        // %5
             text,         // %6
             accent,       // %7
             window,       // %8 (input background)
             onAccent);    // %9
}

} // namespace ModernTheme
