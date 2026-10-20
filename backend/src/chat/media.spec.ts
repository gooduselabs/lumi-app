import { resolveMime, safeFileName, signAttachment, sniffImage, verifyAttachmentSig } from './media';

describe('media validation', () => {
  it('resolves mime from allowlist and extension', () => {
    expect(resolveMime('IMAGE', 'image/png', 'a.png')).toBe('image/png');
    expect(resolveMime('IMAGE', 'application/octet-stream', 'a.jpg')).toBe('image/jpeg');
    expect(resolveMime('FILE', 'application/x-msdownload', 'virus.exe')).toBeNull();
    expect(resolveMime('FILE', 'application/pdf', 'evil.exe')).toBeNull();
    expect(resolveMime('VOICE', 'audio/mp4', 'v.m4a')).toBe('audio/mp4');
    expect(resolveMime('VOICE', 'audio/webm;codecs=opus', 'v.webm')).toBe('audio/webm');
  });
  it('sniffs image magic bytes', () => {
    expect(sniffImage(Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0, 0, 0, 0, 0, 0, 0, 0]))).toBe('image/jpeg');
    expect(sniffImage(Buffer.from('<html><script>alert(1)</script>'))).toBeNull();
  });
  it('sanitizes file names', () => {
    expect(safeFileName('../../etc/passwd', 'x')).toBe('passwd');
    expect(safeFileName('C:\\a\\b "c".pdf', 'x')).toBe('b c.pdf');
    expect(safeFileName('', 'file')).toBe('file');
  });
  it('signs and verifies download URLs', () => {
    const exp = Math.floor(Date.now() / 1000) + 60;
    const sig = signAttachment('s3cret', 'id1', exp);
    expect(verifyAttachmentSig('s3cret', 'id1', exp, sig)).toBe(true);
    expect(verifyAttachmentSig('s3cret', 'id2', exp, sig)).toBe(false);
    expect(verifyAttachmentSig('other', 'id1', exp, sig)).toBe(false);
    expect(verifyAttachmentSig('s3cret', 'id1', exp - 120, signAttachment('s3cret', 'id1', exp - 120))).toBe(false);
  });
});
