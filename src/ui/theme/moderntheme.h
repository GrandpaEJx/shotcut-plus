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

#ifndef MODERNTHEME_H
#define MODERNTHEME_H

#include <QPalette>
#include <QString>

// Additive "Modern" application theme: a flat, single-accent palette and
// stylesheet layered on top of the existing Fusion-based themes in
// MainWindow::changeTheme(). It does not replace or modify the legacy
// dark/light/system themes - it is selected explicitly via the Theme menu
// ("Modern Dark" / "Modern Light") and lives entirely in this module so the
// existing theming code is untouched.
namespace ModernTheme {

QPalette darkPalette();
QPalette lightPalette();

// Qt Style Sheet applied on top of the palette above for widgets that
// Fusion cannot restyle via QPalette alone (tab bars, tooltips, scroll bars).
QString styleSheet(bool dark);

} // namespace ModernTheme

#endif // MODERNTHEME_H
