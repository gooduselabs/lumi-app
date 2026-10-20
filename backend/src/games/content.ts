/** Curated, bilingual content packs for the couple mini-games. Keep it friendly (18+ app, but PG-13). */
export interface Bilingual {
  vi: string;
  en: string;
}
export interface Prompt extends Bilingual {
  id: string;
}

const p = (prefix: string, rows: [string, string][]): Prompt[] => rows.map(([vi, en], i) => ({ id: `${prefix}${i + 1}`, vi, en }));

export const TRUTHS: Prompt[] = p('t', [
  ['Ấn tượng đầu tiên của bạn về mình là gì?', 'What was your first impression of me?'],
  ['Điều gì khiến bạn cười nhiều nhất gần đây?', 'What made you laugh the most recently?'],
  ['Bạn từng nói dối để tránh một buổi hẹn chưa?', 'Have you ever lied to get out of a date?'],
  ['Thói quen kỳ lạ nhất của bạn là gì?', 'What is your weirdest habit?'],
  ['Bài hát nào bạn hay hát một mình nhất?', 'Which song do you sing alone the most?'],
  ['Bạn sợ điều gì nhất?', 'What are you most afraid of?'],
  ['Kỷ niệm đáng xấu hổ nhất thời đi học?', 'Your most embarrassing school memory?'],
  ['Bạn thích được khen về điều gì nhất?', 'What compliment do you love receiving most?'],
  ['Nếu có một ngày làm người vô hình, bạn sẽ làm gì?', 'If you were invisible for a day, what would you do?'],
  ['Điều bạn chưa từng kể với ai?', 'Something you have never told anyone?'],
  ['Món ăn bạn có thể ăn mỗi ngày không chán?', 'A food you could eat every day without getting bored?'],
  ['Crush đầu tiên của bạn như thế nào?', 'What was your first crush like?'],
  ['Bạn đánh giá mình mấy điểm về độ lãng mạn?', 'How romantic are you, out of 10?'],
  ['Điều gì ở người khác khiến bạn mất cảm tình ngay?', 'What instantly turns you off about someone?'],
  ['Lần gần nhất bạn khóc là khi nào?', 'When did you last cry?'],
  ['Ước mơ điên rồ nhất của bạn?', 'Your craziest dream?'],
  ['Nếu được đi du lịch ngay bây giờ, bạn chọn đâu?', 'If you could travel right now, where would you go?'],
  ['Bạn đã từng stalk ai trên mạng xã hội chưa?', 'Have you ever stalked someone on social media?'],
  ['Ba từ mô tả bạn chính xác nhất?', 'Three words that describe you best?'],
  ['Bạn nghĩ gì về mình khi lần đầu trò chuyện?', 'What did you think of me when we first chatted?'],
  ['Thói quen xấu bạn muốn bỏ nhất?', 'Which bad habit do you most want to quit?'],
  ['Bộ phim khiến bạn ám ảnh nhất?', 'Which movie haunted you the most?'],
  ['Bạn tin vào tình yêu sét đánh không?', 'Do you believe in love at first sight?'],
  ['Điều nhỏ nhặt nào làm bạn hạnh phúc cả ngày?', 'What small thing can make your whole day?'],
  ['Biệt danh hồi nhỏ của bạn là gì?', 'What was your childhood nickname?'],
]);

export const DARES: Prompt[] = p('d', [
  ['Gửi một tin nhắn thoại hát 10 giây bất kỳ bài nào.', 'Send a 10-second voice note singing any song.'],
  ['Gửi ảnh chụp màn hình khoá của bạn.', 'Send a screenshot of your lock screen.'],
  ['Kể một câu chuyện cười trong 3 câu.', 'Tell a joke in three sentences.'],
  ['Nói 5 điều bạn thích ở người kia.', 'Say five things you like about the other player.'],
  ['Gửi emoji mô tả ngày hôm nay của bạn (đúng 5 cái).', 'Describe your day using exactly five emojis.'],
  ['Viết một câu thơ tặng người kia.', 'Write a line of poetry for the other player.'],
  ['Đổi ảnh đại diện Lumi sang con vật khác trong 10 phút.', 'Switch your Lumi avatar to another animal for 10 minutes.'],
  ['Nhại giọng một nhân vật hoạt hình qua tin nhắn thoại.', 'Imitate a cartoon character in a voice note.'],
  ['Gửi ảnh món đồ gần bạn nhất bên trái.', 'Send a photo of the nearest object on your left.'],
  ['Khen người kia bằng tiếng Anh (hoặc tiếng Việt nếu bạn nói tiếng Anh).', 'Compliment the other player in Vietnamese (or English if you speak Vietnamese).'],
  ['Kể chuyện bạn vừa làm như một phóng viên thời sự.', 'Describe what you just did like a news reporter.'],
  ['Gửi bài hát bạn đang nghe nhiều nhất.', 'Share the song you have on repeat.'],
  ['Viết tên mình bằng tay không thuận và gửi ảnh.', 'Write your name with your non-dominant hand and send a photo.'],
  ['Cho người kia đặt biệt danh cho bạn trong suốt trò chơi.', 'Let the other player give you a nickname for the rest of the game.'],
  ['Gửi một tấm ảnh bầu trời ngay bây giờ.', 'Send a photo of the sky right now.'],
  ['Nói “mình là thiên tài” 3 lần qua tin nhắn thoại.', 'Say “I am a genius” three times in a voice note.'],
  ['Kể 3 sự thật thú vị về bạn, 1 cái là bịa.', 'Tell three fun facts about you — one is fake.'],
  ['Gửi meme mô tả tính cách của bạn.', 'Send a meme that describes your personality.'],
  ['Vẽ người kia bằng 1 nét và gửi ảnh.', 'Draw the other player in one stroke and send it.'],
  ['Gửi tin nhắn chỉ dùng chữ cái đầu là “L”.', 'Send a sentence where every word starts with “L”.'],
  ['Đọc to câu cuối cùng bạn đã nhắn cho ai đó.', 'Read out the last message you sent to someone else.'],
  ['Nhảy 10 giây và mô tả điệu nhảy bằng lời.', 'Dance for 10 seconds and describe it in words.'],
  ['Dạy người kia một từ trong ngôn ngữ bạn biết.', 'Teach the other player a word in a language you know.'],
  ['Kể giấc mơ gần nhất bạn còn nhớ.', 'Tell the last dream you remember.'],
  ['Gửi 1 lời khuyên bạn muốn nói với chính mình 5 năm trước.', 'Share advice you would give yourself five years ago.'],
]);

export interface KnowQuestion {
  id: string;
  q: Bilingual;
  options: Bilingual[];
}
const kq = (id: string, q: [string, string], opts: [string, string][]): KnowQuestion => ({
  id,
  q: { vi: q[0], en: q[1] },
  options: opts.map(([vi, en]) => ({ vi, en })),
});

export const KNOW_QUESTIONS: KnowQuestion[] = [
  kq('k1', ['Buổi hẹn lý tưởng của mình?', 'My ideal date?'], [['Cà phê yên tĩnh', 'Quiet coffee'], ['Xem phim', 'Movie night'], ['Đi phượt', 'Road trip'], ['Ở nhà nấu ăn', 'Cooking at home']]),
  kq('k2', ['Mình là người…', 'I am a…'], [['Cú đêm', 'Night owl'], ['Chim sớm', 'Early bird'], ['Tuỳ hôm', 'Depends on the day'], ['Ngủ cả ngày', 'Sleep all day']]),
  kq('k3', ['Món mình thích nhất?', 'My favourite food?'], [['Phở / bún', 'Noodle soup'], ['Lẩu', 'Hotpot'], ['Đồ ngọt', 'Desserts'], ['Đồ nướng', 'BBQ']]),
  kq('k4', ['Khi buồn mình thường…', 'When I am sad I…'], [['Nghe nhạc', 'Listen to music'], ['Ăn thật nhiều', 'Eat a lot'], ['Tâm sự với bạn', 'Talk to friends'], ['Ngủ', 'Sleep']]),
  kq('k5', ['Kỳ nghỉ mơ ước?', 'Dream holiday?'], [['Biển', 'Beach'], ['Núi', 'Mountains'], ['Thành phố lớn', 'Big city'], ['Ở nhà', 'Staycation']]),
  kq('k6', ['Mình thích thú cưng nào?', 'Favourite pet?'], [['Chó', 'Dog'], ['Mèo', 'Cat'], ['Cá / chim', 'Fish / bird'], ['Không nuôi', 'None']]),
  kq('k7', ['Ngôn ngữ yêu thương của mình?', 'My love language?'], [['Lời nói', 'Words'], ['Thời gian', 'Quality time'], ['Quà tặng', 'Gifts'], ['Hành động', 'Acts of service']]),
  kq('k8', ['Thể loại phim yêu thích?', 'Favourite movie genre?'], [['Hài', 'Comedy'], ['Kinh dị', 'Horror'], ['Tình cảm', 'Romance'], ['Hành động', 'Action']]),
  kq('k9', ['Cuối tuần mình hay…', 'On weekends I usually…'], [['Đi chơi', 'Go out'], ['Ngủ nướng', 'Sleep in'], ['Làm việc', 'Work'], ['Chơi game', 'Play games']]),
  kq('k10', ['Mùa mình thích nhất?', 'Favourite season?'], [['Xuân', 'Spring'], ['Hạ', 'Summer'], ['Thu', 'Autumn'], ['Đông', 'Winter']]),
  kq('k11', ['Đồ uống mình hay gọi?', 'My usual drink?'], [['Cà phê', 'Coffee'], ['Trà sữa', 'Milk tea'], ['Nước ép', 'Juice'], ['Nước lọc', 'Water']]),
  kq('k12', ['Khi cãi nhau mình…', 'In an argument I…'], [['Im lặng', 'Go quiet'], ['Nói hết', 'Say everything'], ['Xin lỗi trước', 'Apologise first'], ['Đùa cho qua', 'Joke it off']]),
  kq('k13', ['Siêu năng lực mình muốn?', 'Superpower I want?'], [['Bay', 'Flying'], ['Dịch chuyển', 'Teleport'], ['Đọc suy nghĩ', 'Mind reading'], ['Ngừng thời gian', 'Stop time']]),
  kq('k14', ['Mình nghe nhạc gì nhiều nhất?', 'Music I play most?'], [['Pop', 'Pop'], ['Ballad', 'Ballads'], ['Rap / Hip-hop', 'Rap / Hip-hop'], ['Indie / Lo-fi', 'Indie / Lo-fi']]),
  kq('k15', ['Mình sợ nhất…', 'I am most scared of…'], [['Gián', 'Cockroaches'], ['Độ cao', 'Heights'], ['Bóng tối', 'The dark'], ['Cô đơn', 'Being alone']]),
];

export const DRAW_WORDS: Bilingual[] = [
  ['con mèo', 'cat'], ['con chó', 'dog'], ['mặt trời', 'sun'], ['ngôi nhà', 'house'], ['cây', 'tree'], ['xe đạp', 'bicycle'],
  ['máy bay', 'airplane'], ['trái tim', 'heart'], ['con cá', 'fish'], ['bông hoa', 'flower'], ['ô', 'umbrella'], ['kem', 'ice cream'],
  ['mặt trăng', 'moon'], ['ngôi sao', 'star'], ['quả táo', 'apple'], ['điện thoại', 'phone'], ['kính', 'glasses'], ['con rắn', 'snake'],
  ['con thỏ', 'rabbit'], ['bánh sinh nhật', 'birthday cake'], ['núi', 'mountain'], ['cầu vồng', 'rainbow'], ['con bướm', 'butterfly'],
  ['đồng hồ', 'clock'], ['quả chuối', 'banana'], ['ô tô', 'car'], ['con voi', 'elephant'], ['thuyền', 'boat'], ['đàn guitar', 'guitar'],
  ['ly cà phê', 'coffee cup'], ['bóng đèn', 'light bulb'], ['cái ghế', 'chair'], ['con gà', 'chicken'], ['nấm', 'mushroom'],
  ['ốc sên', 'snail'], ['tên lửa', 'rocket'], ['con cua', 'crab'], ['bánh pizza', 'pizza'], ['người tuyết', 'snowman'], ['cái chìa khoá', 'key'],
].map(([vi, en]) => ({ vi, en }));

/** Lowercase, strip Vietnamese diacritics / punctuation / extra spaces — for forgiving guess matching. */
export function normalizeGuess(s: string): string {
  return s
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/đ/g, 'd')
    .replace(/[^a-z0-9 ]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}
