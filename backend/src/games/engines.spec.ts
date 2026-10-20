import { normalizeGuess } from './content';
import { CARO_SIZE, caro, caroWinLine, compatibility, draw, DRAW_ROUNDS, knowMe, KNOW_COUNT, truthDare, TD_ROUNDS } from './engines';

const P: [string, string] = ['A', 'B'];
const rng = () => 0.3;
const at = (r: number, c: number) => r * CARO_SIZE + c;

describe('caro engine', () => {
  it('validates turns, bounds and occupied cells', () => {
    let s = caro.init(P, rng, 0).state;
    expect(() => caro.act(s, 'B', { type: 'place', cell: 0 }, rng, 0)).toThrow('Not your turn');
    s = caro.act(s, 'A', { type: 'place', cell: 0 }, rng, 0).state;
    expect(() => caro.act(s, 'B', { type: 'place', cell: 0 }, rng, 0)).toThrow('Cell taken');
    expect(() => caro.act(s, 'B', { type: 'place', cell: 225 }, rng, 0)).toThrow('Out of board');
    expect(() => caro.act(s, 'B', { type: 'place', cell: 1.5 }, rng, 0)).toThrow('Out of board');
    expect(s.board[0]).toBe('X');
  });

  it('detects five in a row in all directions', () => {
    for (const line of [
      [at(7, 3), at(7, 4), at(7, 5), at(7, 6), at(7, 7)],
      [at(2, 9), at(3, 9), at(4, 9), at(5, 9), at(6, 9)],
      [at(0, 0), at(1, 1), at(2, 2), at(3, 3), at(4, 4)],
      [at(10, 14), at(11, 13), at(12, 12), at(13, 11), at(14, 10)],
    ]) {
      const board = Array(CARO_SIZE * CARO_SIZE).fill('');
      for (const i of line.slice(0, 4)) board[i] = 'X';
      expect(caroWinLine(board, line[3])).toBeNull();
      board[line[4]] = 'X';
      expect(caroWinLine(board, line[4])).toEqual([...line].sort((a, b) => a - b));
    }
  });

  it('plays a full game to a win', () => {
    let s = caro.init(P, rng, 0).state;
    for (let i = 0; i < 4; i++) {
      s = caro.act(s, 'A', { type: 'place', cell: at(5, i) }, rng, 0).state;
      s = caro.act(s, 'B', { type: 'place', cell: at(6, i) }, rng, 0).state;
    }
    s = caro.act(s, 'A', { type: 'place', cell: at(5, 4) }, rng, 0).state;
    expect(caro.over(s)).toBe(true);
    expect(caro.result(s).winnerId).toBe('A');
    expect(() => caro.act(s, 'B', { type: 'place', cell: at(9, 9) }, rng, 0)).toThrow('Game is over');
  });
});

describe('truth or dare engine', () => {
  it('alternates turns, never repeats prompts, finishes after the round limit', () => {
    let s = truthDare.init(P, rng, 0).state;
    const seen = new Set<string>();
    for (let r = 0; r < TD_ROUNDS; r++) {
      const who = r % 2 === 0 ? 'A' : 'B';
      expect(truthDare.turn(s)).toBe(who);
      expect(() => truthDare.act(s, who === 'A' ? 'B' : 'A', { type: 'pick', choice: 'truth' }, rng, 0)).toThrow();
      s = truthDare.act(s, who, { type: 'pick', choice: r % 3 === 0 ? 'dare' : 'random' }, () => Math.random(), 0).state;
      expect(s.prompt).toBeTruthy();
      expect(seen.has(s.prompt!.id)).toBe(false);
      seen.add(s.prompt!.id);
      s = truthDare.act(s, who, { type: r === 1 ? 'skip' : 'done' }, rng, 0).state;
    }
    expect(truthDare.over(s)).toBe(true);
    expect(truthDare.result(s).scores).toEqual({ A: 5, B: 4 });
    expect(truthDare.result(s).winnerId).toBe('A');
  });
});

describe('who-knows-who engine', () => {
  it('hides answers until both answered and scores compatibility', () => {
    let s = knowMe.init(P, rng, 0).state;
    expect(s.questions).toHaveLength(KNOW_COUNT);
    for (let q = 0; q < KNOW_COUNT; q++) {
      s = knowMe.act(s, 'A', { type: 'answer', q, self: 1, guess: q < 3 ? 2 : 0 }, rng, 0).state;
      expect((knowMe.view(s, 'B') as any).answers).toBeNull();
      expect((knowMe.view(s, 'B') as any).answered).toEqual(['A']);
      expect(() => knowMe.act(s, 'A', { type: 'answer', q, self: 0, guess: 0 }, rng, 0)).toThrow('Already answered');
      s = knowMe.act(s, 'B', { type: 'answer', q, self: 2, guess: 1 }, rng, 0).state;
      expect((knowMe.view(s, 'A') as any).answers.B).toEqual({ self: 2, guess: 1 });
      s = knowMe.act(s, 'A', { type: 'next', q }, rng, 0).state;
      s = knowMe.act(s, 'B', { type: 'next', q }, rng, 0).state; // idempotent double tap
    }
    expect(knowMe.over(s)).toBe(true);
    // A guessed B right 3/6, B guessed A right 6/6 → 9/12 = 75%
    expect(knowMe.result(s)).toMatchObject({ scores: { A: 3, B: 6 }, compatibility: 75, winnerId: 'B' });
    expect(compatibility({ A: 0, B: 0 }, 6)).toBe(0);
  });
});

describe('draw & guess engine', () => {
  it('only the drawer draws, guessers see a masked word, a correct guess scores and reveals', () => {
    let step = draw.init(P, rng, 1000);
    expect(step.timerMs).toBeGreaterThan(0);
    let s = step.state;
    expect((draw.view(s, 'B') as any).word).toBeNull();
    expect((draw.view(s, 'A') as any).word).toEqual(s.word);
    expect(() => draw.act(s, 'B', { type: 'stroke', stroke: { c: '#ff0000', w: 4, p: [0, 0, 1, 1] } }, rng, 1000)).toThrow();
    step = draw.act(s, 'A', { type: 'stroke', stroke: { c: '#ff0000', w: 99, p: [0, 0, 2, -1] } }, rng, 1000);
    expect(step.relay?.event).toBe('game:stroke');
    expect(step.state.strokes[0]).toEqual({ c: '#ff0000', w: 40, p: [0, 0, 1, 0] });
    s = draw.act(step.state, 'B', { type: 'guess', text: 'definitely wrong' }, rng, 2000).state;
    expect(s.guesses.at(-1)).toMatchObject({ correct: false });
    // accent-insensitive Vietnamese match
    step = draw.act(s, 'B', { type: 'guess', text: normalizeGuess(s.word.vi).toUpperCase() }, rng, 6000);
    expect(step.state.phase).toBe('reveal');
    expect(step.state.scores.B).toBeGreaterThan(step.state.scores.A);
    expect(step.state.scores.A).toBe(5);
    expect(step.state.guesses.at(-1)).toEqual({ by: 'B', text: '', correct: true });
  });

  it('timer ends rounds, swaps drawer and finishes after the last round', () => {
    let s = draw.init(P, rng, 0).state;
    for (let r = 1; r <= DRAW_ROUNDS; r++) {
      expect(s.round).toBe(r);
      expect(s.drawer).toBe(r % 2 ? 'A' : 'B');
      s = draw.onTimer!(s, rng, 0).state; // drawing -> reveal (nobody guessed)
      expect(s.phase).toBe('reveal');
      s = draw.onTimer!(s, rng, 0).state; // reveal -> next round / finish
    }
    expect(draw.over(s)).toBe(true);
    expect(draw.result(s).winnerId).toBeNull();
  });

  it('normalizes Vietnamese guesses', () => {
    expect(normalizeGuess('  Mặt   Trời! ')).toBe('mat troi');
    expect(normalizeGuess('Đồng hồ')).toBe('dong ho');
  });
});
