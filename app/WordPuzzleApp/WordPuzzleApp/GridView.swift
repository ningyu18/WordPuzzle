import SwiftUI
import WordPuzzleGame

/// The 9x9 Grid of letters, with the live Selection bar drawn on top, found
/// words kept highlighted, and a transient Hint highlight. Handles the Trace
/// gesture: touch a start Cell and drag; the Selection snaps to one of 8
/// Directions (geometry lives in SelectionEngine, in the tested game package).
struct GridView: View {
    let game: GameState

    // Colors for successive found words, cycled by colorSlot.
    private let foundColors: [Color] = [
        .green, .orange, .purple, .pink, .teal, .indigo, .brown,
    ]

    var body: some View {
        GeometryReader { geo in
            let size = game.puzzle.grid.size
            let side = min(geo.size.width, geo.size.height)
            let cell = side / CGFloat(size)

            ZStack(alignment: .topLeading) {
                // Highlight layer: found words + active Hint.
                highlightLayer(cell: cell)

                // Live Selection bar.
                if let sel = game.selection, sel.cells.count > 1 {
                    barPath(for: sel.cells, cell: cell)
                        .fill(Color.accentColor.opacity(0.45))
                }

                // Letters.
                ForEach(0..<size, id: \.self) { row in
                    ForEach(0..<size, id: \.self) { col in
                        Text(String(game.puzzle.grid[Cell(row, col)]))
                            .font(.system(size: cell * 0.5,
                                          weight: .semibold, design: .rounded))
                            .frame(width: cell, height: cell)
                            .position(x: (CGFloat(col) + 0.5) * cell,
                                      y: (CGFloat(row) + 0.5) * cell)
                    }
                }
            }
            .frame(width: side, height: side)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
            .contentShape(Rectangle())
            .gesture(traceGesture(cell: cell, size: size))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: - Highlights

    @ViewBuilder
    private func highlightLayer(cell: CGFloat) -> some View {
        // Found words: colored bars kept on the Grid.
        ForEach(Array(game.found.enumerated()), id: \.offset) { _, fw in
            barPath(for: fw.placement.cells, cell: cell)
                .fill(foundColors[fw.colorSlot % foundColors.count].opacity(0.35))
        }
        // Active Hint: dashed outline over the revealed Placement.
        if let hint = game.hintPlacement {
            barPath(for: hint.cells, cell: cell)
                .stroke(Color.yellow, style: StrokeStyle(
                    lineWidth: 3, lineCap: .round, dash: [6, 4]))
        }
        // Admin reveal-all peek: dashed blue outline over every unfound word,
        // distinct from the yellow single Hint. Non-destructive overlay.
        ForEach(Array(game.revealedPlacements.enumerated()), id: \.offset) { _, placement in
            barPath(for: placement.cells, cell: cell)
                .stroke(Color.blue, style: StrokeStyle(
                    lineWidth: 3, lineCap: .round, dash: [6, 4]))
        }
    }

    /// A rounded capsule bar covering the run of `cells`.
    private func barPath(for cells: [Cell], cell: CGFloat) -> Path {
        guard let first = cells.first, let last = cells.last else {
            return Path()
        }
        let p1 = center(of: first, cell: cell)
        let p2 = center(of: last, cell: cell)
        let width = cell * 0.82
        var path = Path()
        path.move(to: p1)
        path.addLine(to: p2)
        return path.strokedPath(StrokeStyle(
            lineWidth: width, lineCap: .round, lineJoin: .round))
    }

    private func center(of c: Cell, cell: CGFloat) -> CGPoint {
        CGPoint(x: (CGFloat(c.col) + 0.5) * cell,
                y: (CGFloat(c.row) + 0.5) * cell)
    }

    // MARK: - Trace gesture

    private func traceGesture(cell: CGFloat, size: Int) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let start = cellAt(value.startLocation, cell: cell, size: size)
                let finger = cellAt(value.location, cell: cell, size: size)
                guard let start else { return }
                if game.selection == nil {
                    game.beginSelection(at: start)
                }
                if let finger {
                    let before = game.selection?.cells.count ?? 0
                    game.updateSelection(toward: finger)
                    let after = game.selection?.cells.count ?? 0
                    // Optional per-cell tick as the Trace grows (off by default).
                    if SoundEngine.shared.cellTickEnabled, after > before {
                        SoundEngine.shared.playCellTick(step: after - 1)
                    }
                }
            }
            .onEnded { _ in
                // Capture the drag length before ending, since endSelection()
                // clears the live Selection.
                let wasRealAttempt = (game.selection?.cells.count ?? 0) >= 2
                // A non-nil return means a Target Word matched; nil means the
                // drag lined up with nothing.
                if game.endSelection() != nil {
                    // Combo index: the just-found word is the last in `found`.
                    let combo = max(0, game.found.count - 1)
                    SoundEngine.shared.playWordFound(comboIndex: combo)
                } else if wasRealAttempt {
                    // Only sound a no-match on an actual dragged run (2+ cells),
                    // so an incidental tap on a single cell stays silent.
                    SoundEngine.shared.playNoMatch()
                }
            }
    }

    /// Map a point in the Grid's coordinate space to a Cell (clamped in-bounds).
    private func cellAt(_ point: CGPoint, cell: CGFloat, size: Int) -> Cell? {
        guard cell > 0 else { return nil }
        let col = Int(point.x / cell)
        let row = Int(point.y / cell)
        guard row >= 0, row < size, col >= 0, col < size else { return nil }
        return Cell(row, col)
    }
}
