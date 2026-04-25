import { normalizeHandle, validateHandle } from './handle.validator';

describe('normalizeHandle', () => {
  it('lowercases, strips leading @, removes whitespace', () => {
    expect(normalizeHandle('  @MoI 01 ')).toBe('moi01');
  });
});

describe('validateHandle', () => {
  it.each(['mo', '', '  ', '@'])('rejects too-short input %p', (raw) => {
    expect(validateHandle(raw).ok).toBe(false);
  });

  it('rejects too-long handles', () => {
    expect(validateHandle('a'.repeat(21)).ok).toBe(false);
  });

  it('rejects invalid characters', () => {
    expect(validateHandle('moi-daniel').ok).toBe(false);
    expect(validateHandle('moi.daniel').ok).toBe(false);
  });

  it('rejects leading underscore', () => {
    expect(validateHandle('_moi').ok).toBe(false);
  });

  it.each(['admin', 'SMWHR', 'support'])('rejects reserved handle %p', (raw) => {
    expect(validateHandle(raw).ok).toBe(false);
  });

  it.each(['moi', 'sofia', 'beto_bts', 'a1b2c3'])('accepts %p', (raw) => {
    expect(validateHandle(raw).ok).toBe(true);
  });
});
