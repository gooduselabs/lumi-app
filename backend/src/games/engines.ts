import { HttpStatus } from '@nestjs/common';
import { ApiError } from '../common/errors';
import { Bilingual, DARES, DRAW_WORDS, KNOW_QUESTIONS, KnowQuestion, normalizeGuess, Prompt, TRUTHS } from './content';

export type GameKind = 'TRUTH_DARE' | 'KNOW_ME' | 'CARO' | 'DRAW';
export const GAME_KINDS: GameKind[] = ['TRUTH_DARE', 'KNOW_ME', 'CARO', 'DRAW'];

export type Rng = () => number;
export const gameError = (code: string, msg: string) => new ApiError(HttpStatus.BAD_REQUEST, code, msg);

export interface GameResult {
  kind: GameKind;
  winnerId: string | null;
  scores: Record<string, number>;
  /** KNOW_ME only: 0–100 */
  compatibility?: number;
  reason: 'finished' | 'forfeit' | 'abandoned';
}

/** What the engine asks the service to do after an action. */
export interface Step<S> {
  state: S;
  /** (Re)arm the game timer: call `onTimer` after this many ms. `null` clears it. */
  timerMs?: number | null;
  /** Fire-and-forget extra event to the other player (e.g. a drawing stroke). */
  relay?: { event: string; payload: unknown };
}

export interface Engine<S> {
  init(players: [string, string], rng: Rng, now: number): Step<S>;
  act(s: S, by: string, action: Record<string, unknown>, rng: Rng, now: number): Step<S>;
  onTimer?(s: S, rng: Rng, now: number): Step<S>;
  view(s: S, viewer: string): unknown;
  /** Turn holder, for UI hints. */
  turn(s: S): string | null;
  over(s: S): boolean;
  result(s: S): Omit<GameResult, 'kind' | 'reason'>;
}

const other = (players: [string, string], id: string) => (players[0] === id ? players[1] : players[0]);
const pick = <T>(arr: T[], rng: Rng) => arr[Math.floor(rng() * arr.length)];
function shuffle<T>(arr: T[], rng: Rng): T[] {
  const a = [...arr];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(rng() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

// ───────────────────────────── Caro (gomoku 15×15, five in a row) ─────────────────────────────
export const CARO_SIZE = 15;
export interface CaroState {
  players: [string, string]; // players[0] = X, moves first
  board: string[]; // '' | 'X' | 'O'
  next: string;
  moves: number[];
  winner: string | null;
  winLine: number[] | null;
  draw: boolean;
}

/** Returns the winning line (≥5 cells) through `idx`, or null. */
export function caroWinLine(board: string[], idx: number, size = CARO_SIZE): number[] | null {
  const mark = board[idx];
  if (!mark) return null;
  const r0 = Math.floor(idx / size);
  const c0 = idx % size;
  for (const [dr, dc] of [[0, 1], [1, 0], [1, 1], [1, -1]]) {
    const line = [idx];
    for (const dir of [1, -1]) {
      let r = r0 + dr * dir;
      let c = c0 + dc * dir;
      while (r >= 0 && r < size && c >= 0 && c < size && board[r * size + c] === mark) {
        line.push(r * size + c);
        r += dr * dir;
        c += dc * dir;
      }
    }
    if (line.length >= 5) return line.sort((a, b) => a - b);
  }
  return null;
}

export const caro: Engine<CaroState> = {
  init: (players) => ({
    state: { players, board: Array(CARO_SIZE * CARO_SIZE).fill(''), next: players[0], moves: [], winner: null, winLine: null, draw: false },
  }),
  act(s, by, a) {
    if (a.type !== 'place') throw gameError('BAD_ACTION', 'Unknown action');
    if (s.winner || s.draw) throw gameError('GAME_OVER', 'Game is over');
    if (by !== s.next) throw gameError('NOT_YOUR_TURN', 'Not your turn');
    const idx = Number(a.cell);
    if (!Number.isInteger(idx) || idx < 0 || idx >= s.board.length) throw gameError('BAD_MOVE', 'Out of board');
    if (s.board[idx]) throw gameError('BAD_MOVE', 'Cell taken');
    const board = [...s.board];
    board[idx] = by === s.players[0] ? 'X' : 'O';
    const winLine = caroWinLine(board, idx);
    const moves = [...s.moves, idx];
    return {
      state: {
        ...s,
        board,
        moves,
        winLine,
        winner: winLine ? by : null,
        draw: !winLine && moves.length === board.length,
        next: other(s.players, by),
      },
    };
  },
  view: (s) => ({ size: CARO_SIZE, board: s.board, x: s.players[0], last: s.moves.at(-1) ?? null, moves: s.moves.length, winLine: s.winLine }),
  turn: (s) => (s.winner || s.draw ? null : s.next),
  over: (s) => !!s.winner || s.draw,
  result: (s) => ({ winnerId: s.winner, scores: Object.fromEntries(s.players.map((p) => [p, s.winner === p ? 1 : 0])) }),
};

// ───────────────────────────── Truth or Dare ─────────────────────────────
export const TD_ROUNDS = 10;
export interface TruthDareState {
  players: [string, string];
  round: number; // 1-based
  current: string;
  phase: 'choose' | 'prompt';
  choice: 'truth' | 'dare' | null;
  prompt: Prompt | null;
  spin: number; // increments on each pick so clients replay the spin animation
  used: string[];
  stats: Record<string, { done: number; skipped: number }>;
  finished: boolean;
}

export const truthDare: Engine<TruthDareState> = {
  init: (players) => ({
    state: {
      players, round: 1, current: players[0], phase: 'choose', choice: null, prompt: null, spin: 0, used: [],
      stats: Object.fromEntries(players.map((p) => [p, { done: 0, skipped: 0 }])), finished: false,
    },
  }),
  act(s, by, a, rng) {
    if (s.finished) throw gameError('GAME_OVER', 'Game is over');
    if (by !== s.current) throw gameError('NOT_YOUR_TURN', 'Not your turn');
    if (a.type === 'pick') {
      if (s.phase !== 'choose') throw gameError('BAD_ACTION', 'Already picked');
      const c = a.choice === 'truth' || a.choice === 'dare' ? a.choice : rng() < 0.5 ? 'truth' : 'dare';
      const pool = (c === 'truth' ? TRUTHS : DARES).filter((p) => !s.used.includes(p.id));
      const prompt = pick(pool.length ? pool : c === 'truth' ? TRUTHS : DARES, rng);
      return { state: { ...s, phase: 'prompt', choice: c, prompt, spin: s.spin + 1, used: [...s.used, prompt.id] } };
    }
    if (a.type === 'done' || a.type === 'skip') {
      if (s.phase !== 'prompt') throw gameError('BAD_ACTION', 'Pick first');
      const st = { ...s.stats, [by]: { ...s.stats[by] } };
      if (a.type === 'done') st[by].done++;
      else st[by].skipped++;
      const finished = s.round >= TD_ROUNDS;
      return {
        state: { ...s, stats: st, finished, round: finished ? s.round : s.round + 1, current: finished ? s.current : other(s.players, by), phase: 'choose', choice: null, prompt: finished ? s.prompt : null },
      };
    }
    throw gameError('BAD_ACTION', 'Unknown action');
  },
  view: (s) => ({ round: s.round, rounds: TD_ROUNDS, phase: s.phase, choice: s.choice, prompt: s.prompt, spin: s.spin, stats: s.stats }),
  turn: (s) => (s.finished ? null : s.current),
  over: (s) => s.finished,
  result(s) {
    const [a, b] = s.players;
    const da = s.stats[a].done;
    const db = s.stats[b].done;
    return { winnerId: da === db ? null : da > db ? a : b, scores: { [a]: da, [b]: db } };
  },
};

// ───────────────────────────── Who knows who better ─────────────────────────────
export const KNOW_COUNT = 6;
interface KnowAnswer {
  self: number;
  guess: number;
}
export interface KnowMeState {
  players: [string, string];
  questions: KnowQuestion[];
  index: number;
  phase: 'answer' | 'reveal';
  answers: Record<string, KnowAnswer>[]; // per question
  correct: Record<string, number>; // how many times each player guessed the other right
  finished: boolean;
}

export function compatibility(correct: Record<string, number>, questions: number): number {
  const total = Object.values(correct).reduce((a, b) => a + b, 0);
  return Math.round((total / (2 * questions)) * 100);
}

export const knowMe: Engine<KnowMeState> = {
  init: (players, rng) => ({
    state: {
      players, questions: shuffle(KNOW_QUESTIONS, rng).slice(0, KNOW_COUNT), index: 0, phase: 'answer',
      answers: [{}], correct: Object.fromEntries(players.map((p) => [p, 0])), finished: false,
    },
  }),
  act(s, by, a) {
    if (s.finished && a.type === 'next') return { state: s };
    if (s.finished) throw gameError('GAME_OVER', 'Game is over');
    if (a.type === 'answer') {
      if (s.phase !== 'answer' || Number(a.q) !== s.index) throw gameError('BAD_ACTION', 'Not answering this question');
      const n = s.questions[s.index].options.length;
      const self = Number(a.self);
      const guess = Number(a.guess);
      if (![self, guess].every((v) => Number.isInteger(v) && v >= 0 && v < n)) throw gameError('BAD_ACTION', 'Bad option');
      if (s.answers[s.index][by]) throw gameError('BAD_ACTION', 'Already answered');
      const cur = { ...s.answers[s.index], [by]: { self, guess } };
      const answers = [...s.answers];
      answers[s.index] = cur;
      if (Object.keys(cur).length < 2) return { state: { ...s, answers } };
      const [p, q] = s.players;
      const correct = { ...s.correct };
      if (cur[p].guess === cur[q].self) correct[p]++;
      if (cur[q].guess === cur[p].self) correct[q]++;
      return { state: { ...s, answers, correct, phase: 'reveal' } };
    }
    if (a.type === 'next') {
      if (s.phase !== 'reveal' || Number(a.q) !== s.index) return { state: s }; // idempotent: both may tap "next"
      if (s.index + 1 >= s.questions.length) return { state: { ...s, finished: true } };
      return { state: { ...s, index: s.index + 1, phase: 'answer', answers: [...s.answers, {}] } };
    }
    throw gameError('BAD_ACTION', 'Unknown action');
  },
  view(s, viewer) {
    const cur = s.answers[s.index] ?? {};
    const reveal = s.phase === 'reveal' || s.finished;
    return {
      index: s.index,
      count: s.questions.length,
      phase: s.finished ? 'done' : s.phase,
      question: s.questions[s.index],
      answered: Object.keys(cur),
      mine: cur[viewer] ?? null,
      answers: reveal ? cur : null,
      correct: s.correct,
      compatibility: compatibility(s.correct, Math.max(1, s.index + (s.phase === 'reveal' || s.finished ? 1 : 0))),
    };
  },
  turn: () => null,
  over: (s) => s.finished,
  result(s) {
    const [a, b] = s.players;
    return {
      winnerId: s.correct[a] === s.correct[b] ? null : s.correct[a] > s.correct[b] ? a : b,
      scores: s.correct,
      compatibility: compatibility(s.correct, s.questions.length),
    };
  },
};

// ───────────────────────────── Draw & guess ─────────────────────────────
export const DRAW_ROUNDS = 4;
export const DRAW_SECONDS = 75;
export const DRAW_REVEAL_MS = 4000;
export const MAX_STROKES = 600;
export interface Stroke {
  c: string;
  w: number;
  p: number[]; // flat [x0,y0,x1,y1,…] normalized 0..1
}
export interface DrawState {
  players: [string, string];
  round: number;
  drawer: string;
  word: Bilingual;
  phase: 'drawing' | 'reveal';
  endsAt: number;
  strokes: Stroke[];
  guesses: { by: string; text: string; correct: boolean }[];
  scores: Record<string, number>;
  usedWords: string[];
  solved: boolean;
  finished: boolean;
}

function newRound(s: Omit<DrawState, 'word'> & { word?: Bilingual }, rng: Rng, now: number): DrawState {
  const pool = DRAW_WORDS.filter((w) => !s.usedWords.includes(w.en));
  const word = pick(pool.length ? pool : DRAW_WORDS, rng);
  return { ...s, word, phase: 'drawing', endsAt: now + DRAW_SECONDS * 1000, strokes: [], guesses: [], solved: false, usedWords: [...s.usedWords, word.en] } as DrawState;
}

function sanitizeStroke(raw: unknown): Stroke | null {
  if (!raw || typeof raw !== 'object') return null;
  const r = raw as Record<string, unknown>;
  const c = typeof r.c === 'string' && /^#[0-9a-fA-F]{6}$/.test(r.c) ? r.c : '#ffffff';
  const w = Math.min(40, Math.max(1, Number(r.w) || 4));
  if (!Array.isArray(r.p) || r.p.length < 2 || r.p.length > 400) return null;
  const p = r.p.map((v) => Math.min(1, Math.max(0, Math.round(Number(v) * 10000) / 10000)));
  if (p.some((v) => Number.isNaN(v))) return null;
  return { c, w, p };
}

export const draw: Engine<DrawState> = {
  init(players, rng, now) {
    const s = newRound(
      { players, round: 1, drawer: players[0], phase: 'drawing', endsAt: 0, strokes: [], guesses: [], scores: Object.fromEntries(players.map((p) => [p, 0])), usedWords: [], solved: false, finished: false },
      rng,
      now,
    );
    return { state: s, timerMs: DRAW_SECONDS * 1000 };
  },
  act(s, by, a, _rng, now) {
    if (s.finished) throw gameError('GAME_OVER', 'Game is over');
    if (a.type === 'stroke' || a.type === 'clear') {
      if (by !== s.drawer || s.phase !== 'drawing') throw gameError('NOT_YOUR_TURN', 'Only the drawer can draw');
      if (a.type === 'clear') return { state: { ...s, strokes: [] }, relay: { event: 'game:stroke', payload: { clear: true } } };
      const stroke = sanitizeStroke(a.stroke);
      if (!stroke) throw gameError('BAD_ACTION', 'Bad stroke');
      if (s.strokes.length >= MAX_STROKES) throw gameError('BAD_ACTION', 'Canvas full');
      return { state: { ...s, strokes: [...s.strokes, stroke] }, relay: { event: 'game:stroke', payload: { stroke } } };
    }
    if (a.type === 'guess') {
      if (by === s.drawer) throw gameError('NOT_YOUR_TURN', 'The drawer cannot guess');
      if (s.phase !== 'drawing') throw gameError('BAD_ACTION', 'Round is over');
      const text = String(a.text ?? '').trim().slice(0, 40);
      if (!text) throw gameError('BAD_ACTION', 'Empty guess');
      const g = normalizeGuess(text);
      const correct = g === normalizeGuess(s.word.vi) || g === normalizeGuess(s.word.en);
      const guesses = [...s.guesses, { by, text: correct ? '' : text, correct }].slice(-30);
      if (!correct) return { state: { ...s, guesses } };
      const left = Math.max(0, Math.ceil((s.endsAt - now) / 1000));
      const scores = { ...s.scores, [by]: s.scores[by] + 10 + Math.round(left / 5), [s.drawer]: s.scores[s.drawer] + 5 };
      return { state: { ...s, guesses, scores, solved: true, phase: 'reveal', endsAt: now + DRAW_REVEAL_MS }, timerMs: DRAW_REVEAL_MS };
    }
    throw gameError('BAD_ACTION', 'Unknown action');
  },
  onTimer(s, rng, now) {
    if (s.finished) return { state: s, timerMs: null };
    if (s.phase === 'drawing') return { state: { ...s, phase: 'reveal', endsAt: now + DRAW_REVEAL_MS }, timerMs: DRAW_REVEAL_MS };
    if (s.round >= DRAW_ROUNDS) return { state: { ...s, finished: true }, timerMs: null };
    const next = newRound({ ...s, round: s.round + 1, drawer: other(s.players, s.drawer) }, rng, now);
    return { state: next, timerMs: DRAW_SECONDS * 1000 };
  },
  view(s, viewer) {
    const showWord = viewer === s.drawer || s.phase === 'reveal' || s.finished;
    return {
      round: s.round,
      rounds: DRAW_ROUNDS,
      drawer: s.drawer,
      phase: s.finished ? 'done' : s.phase,
      endsAt: s.endsAt,
      seconds: DRAW_SECONDS,
      word: showWord ? s.word : null,
      // Hint for the guesser: letter count per word in both languages.
      hint: { vi: s.word.vi.replace(/[^\s]/g, '_'), en: s.word.en.replace(/[^\s]/g, '_') },
      strokes: s.strokes,
      guesses: s.guesses,
      solved: s.solved,
      scores: s.scores,
    };
  },
  turn: (s) => (s.finished ? null : s.drawer),
  over: (s) => s.finished,
  result(s) {
    const [a, b] = s.players;
    return { winnerId: s.scores[a] === s.scores[b] ? null : s.scores[a] > s.scores[b] ? a : b, scores: s.scores };
  },
};

export const ENGINES: Record<GameKind, Engine<any>> = { CARO: caro, TRUTH_DARE: truthDare, KNOW_ME: knowMe, DRAW: draw };
