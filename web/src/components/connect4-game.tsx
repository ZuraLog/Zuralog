/**
 * Connect4Game — playable Connect 4 easter egg inside the iPhone mockup.
 *
 * Triggered when the user types "connect4" in the waitlist email field.
 * Features:
 * - 7×6 board with drop animations (Framer Motion)
 * - AI opponent using depth-4 minimax with alpha-beta pruning
 * - Win detection (horizontal, vertical, diagonal)
 * - Column hover ghost preview
 * - ZuraLog-themed: sage green (player) vs orange (AI)
 */
'use client';

import { useState, useCallback, useEffect, useRef } from 'react';
import { motion, AnimatePresence } from 'framer-motion';

/* ─── Constants ─────────────────────────────────────────────────────── */
const ROWS = 6;
const COLS = 7;
const EMPTY = 0;
const PLAYER = 1;
const AI = 2;

const PLAYER_COLOR = '#CFE1B9'; // sage
const AI_COLOR = '#FC4C02'; // orange
const BOARD_BG = '#0d1117';
const CELL_BG = '#161b22';

type Board = number[][];
type GameState = 'playing' | 'player_wins' | 'ai_wins' | 'draw';

/* ─── Board Helpers ─────────────────────────────────────────────────── */

function createBoard(): Board {
  return Array.from({ length: ROWS }, () => Array(COLS).fill(EMPTY));
}

function getLowestRow(board: Board, col: number): number {
  for (let r = ROWS - 1; r >= 0; r--) {
    if (board[r][col] === EMPTY) return r;
  }
  return -1;
}

function dropPiece(board: Board, col: number, piece: number): Board | null {
  const row = getLowestRow(board, col);
  if (row === -1) return null;
  const newBoard = board.map((r) => [...r]);
  newBoard[row][col] = piece;
  return newBoard;
}

/** Returns array of [row, col] for winning 4, or null. */
function findWinningLine(board: Board, piece: number): [number, number][] | null {
  // Horizontal
  for (let r = 0; r < ROWS; r++) {
    for (let c = 0; c <= COLS - 4; c++) {
      if (board[r][c] === piece && board[r][c + 1] === piece && board[r][c + 2] === piece && board[r][c + 3] === piece) {
        return [[r, c], [r, c + 1], [r, c + 2], [r, c + 3]];
      }
    }
  }
  // Vertical
  for (let r = 0; r <= ROWS - 4; r++) {
    for (let c = 0; c < COLS; c++) {
      if (board[r][c] === piece && board[r + 1][c] === piece && board[r + 2][c] === piece && board[r + 3][c] === piece) {
        return [[r, c], [r + 1, c], [r + 2, c], [r + 3, c]];
      }
    }
  }
  // Diagonal ↘
  for (let r = 0; r <= ROWS - 4; r++) {
    for (let c = 0; c <= COLS - 4; c++) {
      if (board[r][c] === piece && board[r + 1][c + 1] === piece && board[r + 2][c + 2] === piece && board[r + 3][c + 3] === piece) {
        return [[r, c], [r + 1, c + 1], [r + 2, c + 2], [r + 3, c + 3]];
      }
    }
  }
  // Diagonal ↗
  for (let r = 3; r < ROWS; r++) {
    for (let c = 0; c <= COLS - 4; c++) {
      if (board[r][c] === piece && board[r - 1][c + 1] === piece && board[r - 2][c + 2] === piece && board[r - 3][c + 3] === piece) {
        return [[r, c], [r - 1, c + 1], [r - 2, c + 2], [r - 3, c + 3]];
      }
    }
  }
  return null;
}

function isBoardFull(board: Board): boolean {
  return board[0].every((cell) => cell !== EMPTY);
}

function getValidCols(board: Board): number[] {
  return Array.from({ length: COLS }, (_, i) => i).filter((c) => board[0][c] === EMPTY);
}

/* ─── AI (Minimax with Alpha-Beta) ──────────────────────────────────── */

function scoreWindow(window: number[], piece: number): number {
  const opp = piece === PLAYER ? AI : PLAYER;
  const pieceCount = window.filter((c) => c === piece).length;
  const emptyCount = window.filter((c) => c === EMPTY).length;
  const oppCount = window.filter((c) => c === opp).length;

  if (pieceCount === 4) return 100;
  if (pieceCount === 3 && emptyCount === 1) return 5;
  if (pieceCount === 2 && emptyCount === 2) return 2;
  if (oppCount === 3 && emptyCount === 1) return -4;
  return 0;
}

function evaluateBoard(board: Board, piece: number): number {
  let score = 0;

  // Center column preference
  const centerCol = Math.floor(COLS / 2);
  const centerCount = board.reduce((acc, row) => acc + (row[centerCol] === piece ? 1 : 0), 0);
  score += centerCount * 3;

  // Horizontal
  for (let r = 0; r < ROWS; r++) {
    for (let c = 0; c <= COLS - 4; c++) {
      score += scoreWindow([board[r][c], board[r][c + 1], board[r][c + 2], board[r][c + 3]], piece);
    }
  }
  // Vertical
  for (let r = 0; r <= ROWS - 4; r++) {
    for (let c = 0; c < COLS; c++) {
      score += scoreWindow([board[r][c], board[r + 1][c], board[r + 2][c], board[r + 3][c]], piece);
    }
  }
  // Diagonal ↘
  for (let r = 0; r <= ROWS - 4; r++) {
    for (let c = 0; c <= COLS - 4; c++) {
      score += scoreWindow([board[r][c], board[r + 1][c + 1], board[r + 2][c + 2], board[r + 3][c + 3]], piece);
    }
  }
  // Diagonal ↗
  for (let r = 3; r < ROWS; r++) {
    for (let c = 0; c <= COLS - 4; c++) {
      score += scoreWindow([board[r][c], board[r - 1][c + 1], board[r - 2][c + 2], board[r - 3][c + 3]], piece);
    }
  }

  return score;
}

function minimax(board: Board, depth: number, alpha: number, beta: number, maximizing: boolean): [number | null, number] {
  const validCols = getValidCols(board);

  if (findWinningLine(board, AI)) return [null, 100000];
  if (findWinningLine(board, PLAYER)) return [null, -100000];
  if (validCols.length === 0 || depth === 0) return [null, evaluateBoard(board, AI)];

  if (maximizing) {
    let bestScore = -Infinity;
    let bestCol = validCols[Math.floor(Math.random() * validCols.length)];
    for (const col of validCols) {
      const newBoard = dropPiece(board, col, AI);
      if (!newBoard) continue;
      const [, score] = minimax(newBoard, depth - 1, alpha, beta, false);
      if (score > bestScore) {
        bestScore = score;
        bestCol = col;
      }
      alpha = Math.max(alpha, score);
      if (alpha >= beta) break;
    }
    return [bestCol, bestScore];
  } else {
    let bestScore = Infinity;
    let bestCol = validCols[Math.floor(Math.random() * validCols.length)];
    for (const col of validCols) {
      const newBoard = dropPiece(board, col, PLAYER);
      if (!newBoard) continue;
      const [, score] = minimax(newBoard, depth - 1, alpha, beta, true);
      if (score < bestScore) {
        bestScore = score;
        bestCol = col;
      }
      beta = Math.min(beta, score);
      if (alpha >= beta) break;
    }
    return [bestCol, bestScore];
  }
}

function getAIMove(board: Board): number {
  const [col] = minimax(board, 4, -Infinity, Infinity, true);
  return col ?? getValidCols(board)[0];
}

/* ─── Game Component ────────────────────────────────────────────────── */

export function Connect4Game() {
  const [board, setBoard] = useState<Board>(createBoard);
  const [gameState, setGameState] = useState<GameState>('playing');
  const [winLine, setWinLine] = useState<[number, number][] | null>(null);
  const [hoverCol, setHoverCol] = useState<number | null>(null);
  const [aiThinking, setAiThinking] = useState(false);
  const [scores, setScores] = useState({ player: 0, ai: 0 });
  const isPlayerTurn = useRef(true);

  const checkGameEnd = useCallback((newBoard: Board, piece: number) => {
    const line = findWinningLine(newBoard, piece);
    if (line) {
      setWinLine(line);
      if (piece === PLAYER) {
        setGameState('player_wins');
        setScores((s) => ({ ...s, player: s.player + 1 }));
      } else {
        setGameState('ai_wins');
        setScores((s) => ({ ...s, ai: s.ai + 1 }));
      }
      return true;
    }
    if (isBoardFull(newBoard)) {
      setGameState('draw');
      return true;
    }
    return false;
  }, []);

  const doAIMove = useCallback(
    (currentBoard: Board) => {
      setAiThinking(true);
      // Small delay for "thinking" feel
      setTimeout(() => {
        const col = getAIMove(currentBoard);
        const newBoard = dropPiece(currentBoard, col, AI);
        if (newBoard) {
          setBoard(newBoard);
          if (!checkGameEnd(newBoard, AI)) {
            isPlayerTurn.current = true;
          }
        }
        setAiThinking(false);
      }, 600);
    },
    [checkGameEnd],
  );

  function handleColumnClick(col: number) {
    if (gameState !== 'playing' || !isPlayerTurn.current || aiThinking) return;
    if (board[0][col] !== EMPTY) return;

    const newBoard = dropPiece(board, col, PLAYER);
    if (!newBoard) return;

    setBoard(newBoard);
    isPlayerTurn.current = false;

    if (!checkGameEnd(newBoard, PLAYER)) {
      doAIMove(newBoard);
    }
  }

  function resetGame() {
    setBoard(createBoard());
    setGameState('playing');
    setWinLine(null);
    setHoverCol(null);
    setAiThinking(false);
    isPlayerTurn.current = true;
  }

  // If AI should go first on reset (optional: always let player go first)
  useEffect(() => {
    isPlayerTurn.current = true;
  }, []);

  const isWinCell = (r: number, c: number) =>
    winLine?.some(([wr, wc]) => wr === r && wc === c) ?? false;

  // Cell size — fits 7 columns in ~210px usable width
  const cellSize = 26;
  const gap = 3;

  return (
    <div className="flex h-full flex-col">
      {/* Header */}
      <div className="flex items-center justify-between px-4 pb-2 pt-3">
        <div className="flex items-center gap-2">
          <span className="text-[13px] font-bold text-white">Connect 4</span>
          <span className="rounded-full border border-white/10 bg-white/5 px-1.5 py-0.5 text-[8px] font-semibold text-zinc-400">
            vs AI
          </span>
        </div>
        <div className="flex items-center gap-2 text-[9px] font-semibold">
          <span style={{ color: PLAYER_COLOR }}>{scores.player}</span>
          <span className="text-zinc-600">-</span>
          <span style={{ color: AI_COLOR }}>{scores.ai}</span>
        </div>
      </div>

      {/* Turn indicator */}
      <div className="flex items-center justify-center gap-2 px-4 pb-2">
        {gameState === 'playing' ? (
          <>
            <div
              className="h-2 w-2 rounded-full"
              style={{ backgroundColor: aiThinking ? AI_COLOR : PLAYER_COLOR }}
            />
            <span className="text-[9px] text-zinc-400">
              {aiThinking ? 'AI thinking...' : 'Your turn'}
            </span>
            {aiThinking && (
              <div className="flex gap-0.5">
                <span className="h-1 w-1 animate-pulse rounded-full bg-orange-400" />
                <span className="h-1 w-1 animate-pulse rounded-full bg-orange-400 [animation-delay:150ms]" />
                <span className="h-1 w-1 animate-pulse rounded-full bg-orange-400 [animation-delay:300ms]" />
              </div>
            )}
          </>
        ) : (
          <span
            className="text-[10px] font-bold"
            style={{
              color:
                gameState === 'player_wins'
                  ? PLAYER_COLOR
                  : gameState === 'ai_wins'
                    ? AI_COLOR
                    : '#888',
            }}
          >
            {gameState === 'player_wins' && '🎉 You Win!'}
            {gameState === 'ai_wins' && 'AI Wins!'}
            {gameState === 'draw' && "It's a Draw!"}
          </span>
        )}
      </div>

      {/* Board */}
      <div className="flex flex-1 items-center justify-center px-2">
        <div
          className="relative rounded-xl p-1.5"
          style={{ backgroundColor: BOARD_BG }}
        >
          {/* Column hover zones (invisible, captures clicks) */}
          <div className="absolute inset-0 z-10 flex rounded-xl">
            {Array.from({ length: COLS }, (_, c) => (
              <div
                key={c}
                className="flex-1 cursor-pointer"
                onClick={() => handleColumnClick(c)}
                onMouseEnter={() => setHoverCol(c)}
                onMouseLeave={() => setHoverCol(null)}
              />
            ))}
          </div>

          {/* Ghost piece preview */}
          {hoverCol !== null && gameState === 'playing' && !aiThinking && board[0][hoverCol] === EMPTY && (
            <div
              className="absolute z-0 rounded-full opacity-30"
              style={{
                width: cellSize,
                height: cellSize,
                backgroundColor: PLAYER_COLOR,
                left: hoverCol * (cellSize + gap) + 6,
                top: -cellSize - 4,
              }}
            />
          )}

          {/* Grid */}
          <div
            className="relative grid"
            style={{
              gridTemplateColumns: `repeat(${COLS}, ${cellSize}px)`,
              gridTemplateRows: `repeat(${ROWS}, ${cellSize}px)`,
              gap: `${gap}px`,
            }}
          >
            {board.map((row, r) =>
              row.map((cell, c) => (
                <div
                  key={`${r}-${c}`}
                  className="relative rounded-full"
                  style={{ backgroundColor: CELL_BG, width: cellSize, height: cellSize }}
                >
                  <AnimatePresence>
                    {cell !== EMPTY && (
                      <motion.div
                        key={`piece-${r}-${c}`}
                        className="absolute inset-0 rounded-full"
                        style={{
                          backgroundColor: cell === PLAYER ? PLAYER_COLOR : AI_COLOR,
                          boxShadow: isWinCell(r, c)
                            ? `0 0 8px 2px ${cell === PLAYER ? PLAYER_COLOR : AI_COLOR}`
                            : 'none',
                        }}
                        initial={{ y: -(r + 1) * (cellSize + gap), opacity: 0.7 }}
                        animate={{
                          y: 0,
                          opacity: 1,
                          scale: isWinCell(r, c) ? [1, 1.15, 1] : 1,
                        }}
                        transition={{
                          y: { type: 'spring', stiffness: 300, damping: 20 },
                          scale: isWinCell(r, c)
                            ? { repeat: Infinity, duration: 1.2, ease: 'easeInOut' }
                            : undefined,
                        }}
                      />
                    )}
                  </AnimatePresence>
                </div>
              )),
            )}
          </div>
        </div>
      </div>

      {/* Bottom area */}
      <div className="flex flex-col items-center gap-1.5 px-4 pb-3 pt-2">
        {gameState !== 'playing' && (
          <motion.button
            initial={{ opacity: 0, scale: 0.8 }}
            animate={{ opacity: 1, scale: 1 }}
            onClick={resetGame}
            className="rounded-full bg-sage/20 px-4 py-1.5 text-[10px] font-semibold text-sage transition-colors hover:bg-sage/30"
          >
            Play Again
          </motion.button>
        )}
        <span className="text-[8px] text-zinc-600">Easter egg 🎮</span>
      </div>
    </div>
  );
}
