
// =========================================================================
//  EchoVoice — Frontend + EchoVoice ASR Backend (fine-tuned HuBERT)
// =========================================================================

// ===== Backend Config =====
// Point this at the EchoVoice ASR backend (see Documentation/README_backend.md). It serves
// the HuBERT model fine-tuned on children's speech and turns a recorded
// attempt into a transcript, which is then scored client-side exactly as
// before (WER/PER/phoneme alignment).
const ECHOVOICE_BACKEND_URL = 'http://localhost:8000';

// ===== DOM Refs =====
const $ = id => document.getElementById(id);
const micBtn = $('micBtn');
const micStatus = $('micStatus');
const activeWordPanel = $('activeWordPanel');
const targetWordDisplay = $('targetWordDisplay');
const targetIpaDisplay = $('targetIpaDisplay');
const listenTargetBtn = $('listenTargetBtn');
const micSection = $('micSection');
const resultPanel = $('resultPanel');
const toastEl = $('toast');
const wordGrid = $('wordGrid');
const categorySelector = $('categorySelector');

// ===== CMU-style IPA phoneme dictionary (simplified subset for GFTA words) =====
const WORD_BANK = {
  "Animals": [
    { word: "cat", ipa: "/kæt/" },
    { word: "dog", ipa: "/dɔːɡ/" },
    { word: "fish", ipa: "/fɪʃ/" },
    { word: "bird", ipa: "/bɜːd/" },
    { word: "frog", ipa: "/frɑːɡ/" },
    { word: "duck", ipa: "/dʌk/" },
    { word: "horse", ipa: "/hɔːrs/" },
    { word: "sheep", ipa: "/ʃiːp/" },
    { word: "mouse", ipa: "/maʊs/" },
    { word: "bear", ipa: "/bɛr/" },
  ],
  "Body Parts": [
    { word: "mouth", ipa: "/maʊð/" },
    { word: "nose", ipa: "/noʊz/" },
    { word: "thumb", ipa: "/θʌm/" },
    { word: "teeth", ipa: "/tiːθ/" },
    { word: "hand", ipa: "/hænd/" },
    { word: "foot", ipa: "/fʊt/" },
    { word: "knee", ipa: "/niː/" },
    { word: "head", ipa: "/hɛd/" },
    { word: "ear", ipa: "/iːr/" },
    { word: "arm", ipa: "/ɑːrm/" },
  ],
  "Objects": [
    { word: "ball", ipa: "/bɔːl/" },
    { word: "cup", ipa: "/kʌp/" },
    { word: "spoon", ipa: "/spuːn/" },
    { word: "chair", ipa: "/tʃɛr/" },
    { word: "door", ipa: "/dɔːr/" },
    { word: "book", ipa: "/bʊk/" },
    { word: "shoe", ipa: "/ʃuː/" },
    { word: "house", ipa: "/haʊs/" },
    { word: "truck", ipa: "/trʌk/" },
    { word: "star", ipa: "/stɑːr/" },
  ],
  "Actions": [
    { word: "jump", ipa: "/dʒʌmp/" },
    { word: "run", ipa: "/rʌn/" },
    { word: "sing", ipa: "/sɪŋ/" },
    { word: "clap", ipa: "/klæp/" },
    { word: "smile", ipa: "/smaɪl/" },
    { word: "sleep", ipa: "/sliːp/" },
    { word: "throw", ipa: "/θroʊ/" },
    { word: "push", ipa: "/pʊʃ/" },
    { word: "drink", ipa: "/drɪŋk/" },
    { word: "wash", ipa: "/wɑːʃ/" },
  ],
  "Colors & Numbers": [
    { word: "red", ipa: "/rɛd/" },
    { word: "blue", ipa: "/bluː/" },
    { word: "green", ipa: "/ɡriːn/" },
    { word: "yellow", ipa: "/jɛloʊ/" },
    { word: "three", ipa: "/θriː/" },
    { word: "five", ipa: "/faɪv/" },
    { word: "six", ipa: "/sɪks/" },
    { word: "black", ipa: "/blæk/" },
    { word: "white", ipa: "/waɪt/" },
    { word: "orange", ipa: "/ɔːrʌndʒ/" },
  ]
};

// ===== Category visuals =====
const CATEGORY_META = {
  "Animals":         { icon: "🐾", from: "#ffd93d", to: "#ffb03a" },
  "Body Parts":      { icon: "🧍", from: "#ffb3c1", to: "#ff8fab" },
  "Objects":         { icon: "🧸", from: "#a1c4fd", to: "#c2e9fb" },
  "Actions":         { icon: "⚡", from: "#fbc2eb", to: "#a6c1ee" },
  "Colors & Numbers":{ icon: "🎨", from: "#fddb92", to: "#ffd3a5" },
};

// Image shown on each word flashcard
const WORD_EMOJI = {
  // Animals
  "cat": "🐱", "dog": "🐶", "fish": "🐟", "bird": "🐦", "frog": "🐸",
  "duck": "🦆", "horse": "🐴", "sheep": "🐑", "mouse": "🐭", "bear": "🐻",
  // Body Parts
  "mouth": "👄", "nose": "👃", "thumb": "👍", "teeth": "🦷", "hand": "✋",
  "foot": "🦶", "knee": "🦵", "head": "🧒", "ear": "👂", "arm": "💪",
  // Objects
  "ball": "⚽", "cup": "🥤", "spoon": "🥄", "chair": "🪑", "door": "🚪",
  "book": "📖", "shoe": "👟", "house": "🏠", "truck": "🚚", "star": "⭐",
  // Actions
  "jump": "🦘", "run": "🏃", "sing": "🎤", "clap": "👏", "smile": "😊",
  "sleep": "😴", "throw": "🤾", "push": "🫸", "drink": "🍵", "wash": "🧼",
  // Colors & Numbers
  "red": "🔴", "blue": "🔵", "green": "🟢", "yellow": "🟡", "three": "3️⃣",
  "five": "5️⃣", "six": "6️⃣", "black": "⚫", "white": "⚪", "orange": "🟠",
};

function wordEmoji(word) {
  return WORD_EMOJI[word] || WORD_EMOJI[String(word).toLowerCase()] || "💬";
}

// ===== Phonemization (ARPAbet, via the backend) =====
// The trainer derives reference/hypothesis phonemes with g2p_en -> ARPAbet.
// Scoring therefore MUST use the same inventory, so phonemization lives in the
// backend (POST /api/phonemize) instead of hand-rolled rules in the browser.
// A bundled g2p_en-generated dictionary is the offline fallback.
const ARP2IPA = {
  "AA": "ɑ", "AE": "æ", "AH": "ʌ", "AO": "ɔ", "AW": "aʊ", "AY": "aɪ",
  "B": "b", "CH": "tʃ", "D": "d", "DH": "ð", "EH": "ɛ", "ER": "ɜː", "EY": "eɪ",
  "F": "f", "G": "ɡ", "HH": "h", "IH": "ɪ", "IY": "iː", "JH": "dʒ", "K": "k",
  "L": "l", "M": "m", "N": "n", "NG": "ŋ", "OW": "oʊ", "OY": "ɔɪ", "P": "p",
  "R": "r", "S": "s", "SH": "ʃ", "T": "t", "TH": "θ", "UH": "ʊ", "UW": "uː",
  "V": "v", "W": "w", "Y": "j", "Z": "z",
};

function arpabetToIpa(phones) {
  return (phones || []).map(p => ARP2IPA[p] || p).join(' ');
}

const _phonemeCache = new Map();
let _bundledPhonemes = null;

async function loadBundledPhonemes() {
  if (_bundledPhonemes) return _bundledPhonemes;
  try {
    const res = await fetch('phonemes.json', { cache: 'force-cache' });
    if (!res.ok) throw new Error('HTTP ' + res.status);
    const data = await res.json();
    _bundledPhonemes = {};
    Object.entries(data.words || {}).forEach(([w, p]) => { _bundledPhonemes[w.toLowerCase()] = p; });
  } catch (e) {
    _bundledPhonemes = null;
  }
  return _bundledPhonemes;
}

async function phonemize(text) {
  const key = String(text || '').trim().replace(/\s+/g, ' ').toLowerCase();
  if (!key) return [];
  if (_phonemeCache.has(key)) return _phonemeCache.get(key);

  try {
    const res = await fetch(`${ECHOVOICE_BACKEND_URL}/api/phonemize`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ text: key })
    });
    if (!res.ok) {
      let detail = res.statusText;
      try { detail = (await res.json()).detail || detail; } catch (e) {}
      throw new Error(detail);
    }
    const data = await res.json();
    _phonemeCache.set(key, data.phonemes || []);
    return data.phonemes || [];
  } catch (e) {
    // Backend unreachable: fall back to the bundled g2p_en dictionary so the
    // scored inventory stays identical to training. Never fall back to rules.
    const bundle = await loadBundledPhonemes();
    if (bundle && bundle[key]) {
      _phonemeCache.set(key, bundle[key]);
      return bundle[key];
    }
    // Non-words (e.g. noise symbols) will not have phonemes. Treat as empty
    // array so alignment/PER produces a defensible score (typically 0) rather
    // than throwing and aborting the attempt. The backend already does g2p_en;
    // this is the offline fallback path only.
    _phonemeCache.set(key, []);
    return [];
  }
}

// Warm the cache for the words about to be practised (avoids a stall on click).
async function prefetchPhonemes(words) {
  const list = Array.isArray(words) ? words : [words];
  await Promise.all(list.map(w => phonemize(w).catch(() => null)));
}

// ===== Levenshtein Alignment with backtrace =====
function levenshteinAlign(ref, hyp) {
  const n = ref.length;
  const m = hyp.length;
  // DP table
  const dp = Array.from({length: n+1}, () => new Array(m+1).fill(0));
  for (let i = 0; i <= n; i++) dp[i][0] = i;
  for (let j = 0; j <= m; j++) dp[0][j] = j;

  for (let i = 1; i <= n; i++) {
    for (let j = 1; j <= m; j++) {
      if (ref[i-1] === hyp[j-1]) {
        dp[i][j] = dp[i-1][j-1];
      } else {
        dp[i][j] = 1 + Math.min(
          dp[i-1][j-1], // substitution
          dp[i-1][j],   // deletion
          dp[i][j-1]    // insertion
        );
      }
    }
  }

  // Backtrace
  const alignment = [];
  let i = n, j = m;
  while (i > 0 || j > 0) {
    if (i > 0 && j > 0 && ref[i-1] === hyp[j-1]) {
      alignment.unshift({ type: 'correct', ref: ref[i-1], hyp: hyp[j-1] });
      i--; j--;
    } else if (i > 0 && j > 0 && dp[i][j] === dp[i-1][j-1] + 1) {
      alignment.unshift({ type: 'substitution', ref: ref[i-1], hyp: hyp[j-1] });
      i--; j--;
    } else if (i > 0 && dp[i][j] === dp[i-1][j] + 1) {
      alignment.unshift({ type: 'deletion', ref: ref[i-1], hyp: null });
      i--;
    } else {
      alignment.unshift({ type: 'insertion', ref: null, hyp: hyp[j-1] });
      j--;
    }
  }

  const subs = alignment.filter(a => a.type === 'substitution').length;
  const dels = alignment.filter(a => a.type === 'deletion').length;
  const ins  = alignment.filter(a => a.type === 'insertion').length;
  const correct = alignment.filter(a => a.type === 'correct').length;

  return { alignment, subs, dels, ins, correct, editDistance: dp[n][m] };
}

// ===== WER & PER Calculation =====
function computeWER(refText, hypText) {
  const refWords = refText.toLowerCase().replace(/[^a-z\s]/g,'').trim().split(/\s+/).filter(w=>w);
  const hypWords = hypText.toLowerCase().replace(/[^a-z\s]/g,'').trim().split(/\s+/).filter(w=>w);
  const result = levenshteinAlign(refWords, hypWords);
  const wer = refWords.length > 0 ? ((result.subs + result.dels + result.ins) / refWords.length) * 100 : 0;
  return { ...result, wer, refWords, hypWords };
}

function computePER(refPhonemes, hypPhonemes) {
  const result = levenshteinAlign(refPhonemes, hypPhonemes);
  const per = refPhonemes.length > 0 ? ((result.subs + result.dels + result.ins) / refPhonemes.length) * 100 : 0;
  const accuracy = Math.max(0, 100 - per);
  return { ...result, per, accuracy };
}

// ===== State =====
let currentCategory = Object.keys(WORD_BANK)[0];
let selectedWord = null;
let isRecording = false;
let isProcessing = false;
let mediaRecorder = null;
let recordedChunks = [];
// Session history is stored per account so records never leak between users.
const HISTORY_KEY_PREFIX = 'echovoice_history_';
let sessionHistory = [];

function historyKey(user) {
  return HISTORY_KEY_PREFIX + (user || 'guest');
}

function loadHistoryForUser(user) {
  try {
    const raw = localStorage.getItem(historyKey(user));
    sessionHistory = raw ? JSON.parse(raw) : [];
  } catch (e) {
    sessionHistory = [];
  }
  if (!Array.isArray(sessionHistory)) sessionHistory = [];
  renderWordGrid();
  renderHistory();
  updateReportSummary();
}

// ===== Transcription engine =====
// Transcription engines, in priority order:
//   1. backend HuBERT, when ECHOVOICE_ENABLE_ASR=1 and the model loaded
//   2. browser Web Speech API, when HuBERT is switched off
//   3. a clearly-labelled on-device simulation, so the UI is never dead-ended
// Whatever produces the text, scoring runs through the backend's g2p_en
// phonemizer, so feedback, reports and exports behave identically in all modes.
const SpeechRecognitionCtor = window.SpeechRecognition || window.webkitSpeechRecognition;
const hasWebSpeech = !!SpeechRecognitionCtor;
const hasMediaRecorder = !!(navigator.mediaDevices && navigator.mediaDevices.getUserMedia && window.MediaRecorder);
// The mic needs either engine; checkBackend() decides which one is live.
const hasRecordingSupport = hasWebSpeech || hasMediaRecorder;
if (!hasRecordingSupport) {
  $('unsupported').style.display = 'block';
  micBtn.disabled = true;
}

// Which engine produced the transcript for the current attempt. Stamped onto
// every history record so a simulated score is never mistaken for a measured
// one in the history, the CSV export, or the clinician report.
const ASR_ENGINE = {
  WEB_SPEECH: 'browser-speech-recognition',
  BACKEND: 'echovoice-hubert-asr',
  SIMULATED: 'simulated-no-transcriber'
};

let webSpeechRecognition = null;

// Set from /api/health. When the backend has an acoustic model loaded we must
// actually use it - the browser API is only the fallback for when HuBERT is
// switched off. Without this the frontend would silently keep using the
// browser even with ECHOVOICE_ENABLE_ASR=1.
let backendAsrAvailable = false;

// Pick the transcription engine for this attempt, in priority order:
//   1. backend HuBERT (the real pipeline, when it is enabled and reachable)
//   2. browser Web Speech API (no-HuBERT mode)
//   3. simulation, when neither can transcribe
function pickAsrEngine() {
  if (backendAsrAvailable) return ASR_ENGINE.BACKEND;
  if (hasWebSpeech) return ASR_ENGINE.WEB_SPEECH;
  return ASR_ENGINE.SIMULATED;
}

// ===== Backend Health Check =====
async function checkBackend() {
  $('backendUrlLabel').textContent = ECHOVOICE_BACKEND_URL;
  try {
    const res = await fetch(`${ECHOVOICE_BACKEND_URL}/api/health`, { method: 'GET' });
    if (!res.ok) throw new Error('bad status');
    const data = await res.json();
    $('backendOffline').style.display = 'none';
    backendAsrAvailable = !!data.model_available;
    if (backendAsrAvailable) {
      $('asrEngineLabel').textContent = 'ASR: ' + data.model_source + (data.fine_tuned ? '' : ' (base, not child-speech)');
    } else {
      $('asrEngineLabel').textContent = hasWebSpeech
        ? 'ASR: browser speech recognition'
        : 'ASR: simulated (no transcriber available)';
    }
    // The acoustic model is optional; only warn when the browser cannot
    // transcribe either, because then nothing can produce a real score.
    if (!backendAsrAvailable && !hasWebSpeech) {
      showToast('⚠️ No speech transcriber available - scores will be simulated.');
    } else if (backendAsrAvailable && data.fine_tuned === false) {
      showToast('ℹ️ Backend ASR is the base model, not the child-speech fine-tuned checkpoint.');
    }
  } catch (e) {
    $('backendOffline').style.display = 'block';
    backendAsrAvailable = false;
    $('asrEngineLabel').textContent = hasWebSpeech
      ? 'ASR: browser speech recognition (backend offline)'
      : 'ASR: simulated (backend offline, no transcriber)';
  }
}
if (hasRecordingSupport) checkBackend();

// ===== Profile persistence (backend) =====
let currentChildId = localStorage.getItem('echovoice_child_id') || null;

async function saveProfileToBackend() {
  const name = $('childName').value.trim();
  const ageVal = $('childAge').value.trim();
  const sessionDate = $('sessionDate').value;
  if (!name) { showToast('⚠️ Enter the child\'s name first.'); return; }
  const payload = {
    name: name,
    age_years: ageVal ? Number(ageVal) : null,
    session_date: sessionDate || null
  };
  if (currentChildId) payload.child_id = currentChildId;
  try {
    const res = await fetch(`${ECHOVOICE_BACKEND_URL}/api/profile`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });
    if (!res.ok) throw new Error(((await res.json()).detail) || res.statusText);
    const data = await res.json();
    currentChildId = data.child_id;
    localStorage.setItem('echovoice_child_id', currentChildId);
    $('profileSaveMsg').textContent = '✔ Profile saved to backend (' + new Date().toLocaleTimeString() + ')';
    showToast('💾 Profile saved to backend.');
    renderProfilePage();
  } catch (e) {
    $('profileSaveMsg').textContent = '✖ Save failed';
    showToast('⚠️ Could not save profile: ' + e.message);
  }
}

async function loadProfileFromBackend() {
  try {
    const res = await fetch(`${ECHOVOICE_BACKEND_URL}/api/profile`, { method: 'GET' });
    if (!res.ok) return;
    const data = await res.json();
    currentChildId = data.child_id;
    localStorage.setItem('echovoice_child_id', currentChildId);
    $('childName').value = data.name || '';
    if (data.age_years != null) $('childAge').value = data.age_years;
    if (data.session_date) $('sessionDate').value = data.session_date;
  } catch (e) { /* backend offline → keep whatever is in the fields */ }
}

$('saveProfileBtn').addEventListener('click', saveProfileToBackend);
// Profile is intentionally NOT auto-loaded: each login starts with a blank child profile.

// ===== Send recorded audio to the EchoVoice ASR backend =====
let demoMode = false;

function enableDemoMode(reason) {
  if (!demoMode) {
    demoMode = true;
    $('demoModeBanner').style.display = 'block';
    $('backendOffline').style.display = 'none';
    console.warn('[EchoVoice] Demo mode enabled:', reason);
  }
}

function disableDemoMode() {
  demoMode = false;
  $('demoModeBanner').style.display = 'none';
  $('backendOffline').style.display = 'none';
}

// Simulate a plausible attempt on-device so every feature stays usable without the model.
function simulateTranscript(target) {
  // With no target word there is nothing to perturb, and returning '' would
  // produce an empty transcript that cannot be scored.
  if (!target) return 'word';
  const attempts = [target, target, target, target];
  // Introduce a realistic error most of the time so PER/WER are not always zero.
  if (Math.random() > 0.35) {
    const vowels = ['a', 'e', 'i', 'o', 'u'];
    const idx = target.search(/[aeiou]/i);
    if (idx > -1) {
      const wrong = vowels[(vowels.indexOf(target[idx].toLowerCase()) + 1 + Math.floor(Math.random() * 3)) % 5];
      return target.slice(0, idx) + wrong + target.slice(idx + 1);
    }
    return target.slice(0, -1);
  }
  return attempts[0];
}

async function transcribeWithBackend(blob) {
  const form = new FormData();
  form.append('audio', blob, 'attempt.webm');

  // Returns { text, asrEngine } so the caller can record which engine actually
  // produced the transcript. A simulated fallback must never be stamped as a
  // backend measurement.
  let res;
  try {
    res = await fetch(`${ECHOVOICE_BACKEND_URL}/api/transcribe`, {
      method: 'POST',
      body: form
    });
  } catch (e) {
    // Backend unreachable -> degrade to on-device simulation.
    enableDemoMode('backend unreachable');
    return { text: simulateTranscript(selectedWord ? selectedWord.word : ''), asrEngine: ASR_ENGINE.SIMULATED };
  }

  if (res.status === 503) {
    // Model not loaded -> degrade to on-device simulation.
    enableDemoMode('ASR model unavailable (503)');
    return { text: simulateTranscript(selectedWord ? selectedWord.word : ''), asrEngine: ASR_ENGINE.SIMULATED };
  }

  if (!res.ok) {
    let detail = res.statusText;
    try { detail = (await res.json()).detail || detail; } catch (e) {}
    throw new Error(detail);
  }

  disableDemoMode();
  const data = await res.json();
  return { text: data.transcript, asrEngine: ASR_ENGINE.BACKEND };
}

// ===== Hamburger drawer + navigation =====
const appDrawer = $('appDrawer');
const drawerBackdrop = $('drawerBackdrop');
const hamburgerBtn = $('hamburgerBtn');
const profileIconBtn = $('profileIconBtn');
const drawerClose = $('drawerClose');

function setDrawer(open) {
  appDrawer.classList.toggle('open', open);
  drawerBackdrop.classList.toggle('open', open);
  appDrawer.setAttribute('aria-hidden', String(!open));
  hamburgerBtn.setAttribute('aria-expanded', String(open));
  hamburgerBtn.setAttribute('aria-label', open ? 'Close menu' : 'Open menu');
  document.body.style.overflow = open ? 'hidden' : '';
  if (open) drawerClose.focus();
}

function showTab(tab) {
  const target = document.querySelector('.drawer-item[data-tab="' + tab + '"]');
  document.querySelectorAll('.drawer-item').forEach(i => i.classList.remove('active'));
  document.querySelectorAll('.section').forEach(s => s.classList.remove('active'));
  if (target) target.classList.add('active');
  $('section-' + tab).classList.add('active');
  if (tab === 'history') renderHistory();
  if (tab === 'report') updateReportSummary();
  if (tab === 'profile') renderProfilePage();
}

hamburgerBtn.addEventListener('click', () => setDrawer(!appDrawer.classList.contains('open')));
profileIconBtn.addEventListener('click', () => { showTab('profile'); setDrawer(false); });
$('drawerProfileBtn').addEventListener('click', () => { showTab('profile'); setDrawer(false); });
drawerClose.addEventListener('click', () => setDrawer(false));
drawerBackdrop.addEventListener('click', () => setDrawer(false));
document.addEventListener('keydown', e => {
  if (e.key === 'Escape' && appDrawer.classList.contains('open')) setDrawer(false);
});

function renderProfileIdentity() {
  const username = currentUser();
  const initial = username ? username.charAt(0).toUpperCase() : '👤';
  $('drawerUsername').textContent = username || 'Signed out';
  $('profileAvatar').textContent = initial;
  $('drawerAvatar').textContent = initial;
  $('profilePageAvatar').textContent = username ? initial : '👤';
}

document.querySelectorAll('.drawer-item').forEach(item => {
  item.addEventListener('click', () => {
    showTab(item.dataset.tab);
    setDrawer(false);
  });
});

// ===== Category Selector (image cards) =====
function renderCategories() {
  categorySelector.innerHTML = '';
  categorySelector.className = 'category-grid';
  Object.keys(WORD_BANK).forEach(cat => {
    const words = WORD_BANK[cat];
    const meta = CATEGORY_META[cat] || { icon: "📚", from: "#dcd6ff", to: "#c9c2ff" };

    const card = document.createElement('button');
    card.type = 'button';
    card.className = 'category-card' + (cat === currentCategory ? ' active' : '');
    card.style.setProperty('--cat-from', meta.from);
    card.style.setProperty('--cat-to', meta.to);
    card.setAttribute('aria-pressed', cat === currentCategory ? 'true' : 'false');

    // Preview strip of the first few word images
    const preview = words.slice(0, 4)
      .map(w => `<span class="category-preview">${wordEmoji(w.word)}</span>`).join('');

    card.innerHTML = `
      <span class="category-image">${meta.icon}</span>
      <span class="category-name">${cat}</span>
      <span class="category-count">${words.length} words</span>
      <span class="category-previews">${preview}</span>
    `;

    card.addEventListener('click', () => {
      if (currentCategory === cat) return;
      currentCategory = cat;
      selectedWord = null;
      activeWordPanel.style.display = 'none';
      micSection.style.display = 'none';
      resultPanel.style.display = 'none';
      renderCategories();
      renderWordGrid();
      wordGrid.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
    });

    categorySelector.appendChild(card);
  });
}

// ===== Word Grid (flashcards) =====
function renderWordGrid() {
  wordGrid.innerHTML = '';
  const words = WORD_BANK[currentCategory];
  words.forEach(item => {
    const card = document.createElement('div');
    card.className = 'word-card';
    card.tabIndex = 0;
    card.setAttribute('role', 'button');
    if (selectedWord && selectedWord.word === item.word) card.classList.add('selected');
    // Check if tested
    if (sessionHistory.some(h => h.targetWord === item.word)) card.classList.add('tested');

    card.innerHTML = `
      <button class="listen-icon" title="Listen" aria-label="Listen to ${item.word}">🔊</button>
      <div class="word-image">${wordEmoji(item.word)}</div>
      <div class="word-text">${item.word}</div>
      <div class="word-ipa">${item.ipa}</div>
    `;

    // Listen button on card
    card.querySelector('.listen-icon').addEventListener('click', (e) => {
      e.stopPropagation();
      speakWord(item.word);
    });

    // Select word
    card.addEventListener('click', () => selectWord(item));
    card.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); selectWord(item); }
    });
    wordGrid.appendChild(card);
  });
}

function selectWord(item) {
  selectedWord = item;
  renderWordGrid();
  activeWordPanel.style.display = 'block';
  micSection.style.display = 'flex';
  resultPanel.style.display = 'none';
  targetWordDisplay.textContent = item.word;
  targetIpaDisplay.textContent = item.ipa;
  activeWordPanel.scrollIntoView({ behavior: 'smooth', block: 'center' });
}

// ===== Random Word Practice =====
function pickRandomWord() {
  const words = WORD_BANK[currentCategory];
  const tested = new Set(sessionHistory.map(h => h.targetWord));
  const untested = words.filter(w => !tested.has(w.word));
  const pool = untested.length ? untested : words;
  const item = pool[Math.floor(Math.random() * pool.length)];
  selectWord(item);
  setTimeout(() => speakWord(item.word), 250);
  showToast(`🎲 Random word picked: "${item.word}" — listen and speak it back!`);
}

$('randomWordBtn').addEventListener('click', () => {
  if (isRecording || isProcessing) return;
  pickRandomWord();
});

$('randomHearAgainBtn').addEventListener('click', () => {
  if (selectedWord) speakWord(selectedWord.word);
});

// ===== Custom Word Practice =====
function useCustomWord(word) {
  const trimmed = (word || '').trim().replace(/\s+/g, ' ');
  if (!trimmed) { showToast('⚠️ Type a word or phrase first.'); return false; }

  let bankMatch = null;
  for (const cat of Object.values(WORD_BANK)) {
    const f = cat.find(w => w.word.toLowerCase() === trimmed.toLowerCase());
    if (f) { bankMatch = f; break; }
  }

  // Reference phonemes always come from the backend; IPA is derived from them
  // so the display and the scored inventory can never disagree.
  selectedWord = { word: trimmed, ipa: bankMatch ? bankMatch.ipa : '/' };
  renderWordGrid();
  activeWordPanel.style.display = 'block';
  micSection.style.display = 'flex';
  resultPanel.style.display = 'none';
  targetWordDisplay.textContent = selectedWord.word;
  targetIpaDisplay.textContent = selectedWord.ipa;

  phonemize(trimmed)
    .then(phones => {
      if (selectedWord && selectedWord.word === trimmed && !bankMatch) {
        selectedWord.ipa = '/' + arpabetToIpa(phones) + '/';
        targetIpaDisplay.textContent = selectedWord.ipa;
      }
    })
    .catch(e => {
      if (selectedWord && selectedWord.word === trimmed) {
        targetIpaDisplay.textContent = '—';
      }
      showToast('⚠️ ' + e.message);
    });

  setTimeout(() => speakWord(trimmed), 200);
  activeWordPanel.scrollIntoView({ behavior: 'smooth', block: 'center' });
  return true;
}

$('customWordBtn').addEventListener('click', () => {
  if (isRecording || isProcessing) return;
  useCustomWord($('customWordInput').value);
});

$('customWordInput').addEventListener('keydown', (e) => {
  if (e.key === 'Enter' && !isRecording && !isProcessing) {
    useCustomWord($('customWordInput').value);
  }
});

$('customHearAgainBtn').addEventListener('click', () => {
  if (selectedWord) speakWord(selectedWord.word);
});

// ===== TTS =====
function speakWord(word) {
  speechSynthesis.cancel();
  const utter = new SpeechSynthesisUtterance(word);
  utter.rate = 0.8;
  utter.pitch = 1.1;
  utter.lang = 'en-US';
  speechSynthesis.speak(utter);
}

listenTargetBtn.addEventListener('click', () => {
  if (selectedWord) speakWord(selectedWord.word);
});

// ===== Mic Control =====
micBtn.addEventListener('click', () => {
  if (!hasRecordingSupport || !selectedWord || isProcessing) return;
  if (isRecording) { stopRecording(); }
  else if (backendAsrAvailable || !hasWebSpeech) { startRecording(); }
  else { startWebSpeech(); }
});

async function startRecording() {
  try {
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    recordedChunks = [];

    // Prefer a widely-supported container; MediaRecorder picks a sensible
    // default codec (webm/opus in Chrome/Edge) if we don't force one.
    const mimeCandidates = ['audio/webm', 'audio/ogg', 'audio/mp4'];
    const mimeType = mimeCandidates.find(t => window.MediaRecorder.isTypeSupported && MediaRecorder.isTypeSupported(t));

    mediaRecorder = mimeType ? new MediaRecorder(stream, { mimeType }) : new MediaRecorder(stream);

    mediaRecorder.ondataavailable = (e) => {
      if (e.data && e.data.size > 0) recordedChunks.push(e.data);
    };

    mediaRecorder.onstop = () => {
      stream.getTracks().forEach(track => track.stop());
      const blob = new Blob(recordedChunks, { type: mediaRecorder.mimeType || 'audio/webm' });
      handleRecordedAudio(blob);
    };

    mediaRecorder.start();
    isRecording = true;
    micBtn.classList.add('recording');
    micBtn.textContent = '⏹️';
    micStatus.textContent = 'Listening… Say the word!';
    micStatus.classList.add('active');
  } catch (err) {
    isRecording = false;
    showToast('🎤 Please allow microphone access!');
  }
}

function stopRecording() {
  isRecording = false;
  micBtn.classList.remove('recording');
  if (webSpeechRecognition) {
    try { webSpeechRecognition.stop(); } catch (e) {}
    webSpeechRecognition = null;
    return;
  }
  if (mediaRecorder && mediaRecorder.state !== 'inactive') {
    mediaRecorder.stop(); // triggers onstop -> handleRecordedAudio
  }
}

// Transcribe one utterance with the browser's Web Speech API. This is the
// default engine: it needs no acoustic model on the server and no torch.
function startWebSpeech() {
  const recognition = new SpeechRecognitionCtor();
  webSpeechRecognition = recognition;
  recognition.lang = 'en-US';
  recognition.interimResults = false;
  recognition.maxAlternatives = 3;
  recognition.continuous = false;

  let settled = false;
  const finish = () => {
    if (settled) return;
    settled = true;
    isRecording = false;
    isProcessing = false;
    webSpeechRecognition = null;
    micBtn.classList.remove('recording');
    micBtn.textContent = '🎙️';
    micStatus.classList.remove('active');
    micStatus.textContent = 'Tap to speak the word!';
  };

  recognition.onresult = event => {
    const results = event.results;
    let best = '';
    let bestConfidence = -1;
    for (let i = 0; i < results.length; i++) {
      const alt = results[i][0];
      const confidence = typeof alt.confidence === 'number' && alt.confidence > 0 ? alt.confidence : 0.5;
      if (confidence > bestConfidence) { bestConfidence = confidence; best = alt.transcript; }
    }
    finish();
    const spokenText = String(best || '').trim().toLowerCase();
    if (!spokenText) {
      micStatus.textContent = 'Tap to speak the word!';
      showToast("🤔 Didn't catch that. Try again!");
      return;
    }
    isProcessing = true;
    micBtn.textContent = '⏳';
    micStatus.textContent = 'Scoring with EchoVoice…';
    disableDemoMode();
    analyzeAttempt(spokenText, ASR_ENGINE.WEB_SPEECH)
      .catch(e => showToast('⚠️ Scoring failed: ' + e.message))
      .finally(() => {
        isProcessing = false;
        micBtn.textContent = '🎙️';
        micStatus.textContent = 'Tap to speak the word!';
      });
  };

  recognition.onerror = event => {
    finish();
    const reason = event && event.error ? event.error : 'unknown';
    if (reason === 'not-allowed' || reason === 'service-not-allowed') {
      showToast('🎤 Microphone permission was denied. Allow mic access and try again.');
      micStatus.textContent = 'Microphone blocked';
      return;
    }
    if (reason === 'no-speech') {
      showToast("🤔 Didn't hear anything. Try again!");
      micStatus.textContent = 'Tap to speak the word!';
      return;
    }
    // 'network', 'audio-capture', 'aborted' and anything else: degrade rather
    // than leave the child stuck on a spinner.
    console.warn('[EchoVoice] Web Speech failed (' + reason + '); simulating.');
    enableDemoMode('speech recognition failed: ' + reason);
    handleSimulatedAttempt(reason);
  };

  recognition.onend = () => {
    if (!settled) {
      finish();
      showToast("🤔 Didn't catch that. Try again!");
    }
  };

  try {
    recognition.start();
    isRecording = true;
    isProcessing = true;
    micBtn.classList.add('recording');
    micBtn.textContent = '⏹️';
    micStatus.textContent = 'Listening… say the word!';
    micStatus.classList.add('active');
  } catch (e) {
    finish();
    enableDemoMode('speech recognition could not start');
    handleSimulatedAttempt('start-failed');
  }
}

// Last-resort path so a practice session is never dead-ended. Always labelled
// as simulated so it cannot be mistaken for a measurement.
function handleSimulatedAttempt(reason) {
  isProcessing = true;
  micBtn.textContent = '⏳';
  micStatus.textContent = 'Scoring a simulated attempt…';
  const target = selectedWord ? selectedWord.word : '';
  const spokenText = simulateTranscript(target);
  analyzeAttempt(spokenText, ASR_ENGINE.SIMULATED)
    .catch(e => showToast('⚠️ Scoring failed: ' + e.message))
    .finally(() => {
      isProcessing = false;
      micBtn.textContent = '🎙️';
      micStatus.textContent = 'Tap to speak the word!';
      micStatus.classList.remove('active');
    });
}

async function handleRecordedAudio(blob) {
  if (blob.size < 500) {
    micStatus.textContent = 'Tap to speak the word!';
    micStatus.classList.remove('active');
    showToast("🤔 Didn't hear anything. Try again!");
    return;
  }

  isProcessing = true;
  micBtn.textContent = '⏳';
  micStatus.textContent = 'Analyzing with EchoVoice ASR…';

  try {
    const result = await transcribeWithBackend(blob);
    if (!result || !result.text) {
      showToast("🤔 Didn't catch that. Try again!");
    } else {
      await analyzeAttempt(result.text, result.asrEngine);
    }
  } catch (err) {
    $('backendOffline').style.display = 'block';
    showToast('⚠️ Could not reach the ASR backend: ' + err.message);
  } finally {
    isProcessing = false;
    micBtn.textContent = '🎙️';
    micStatus.textContent = 'Tap to speak the word!';
    micStatus.classList.remove('active');
  }
}

// ===== Analysis Engine =====
// Both the target and the ASR hypothesis are phonemized by the backend so PER
// is always measured in the same ARPAbet inventory used during training.
async function analyzeAttempt(spokenText, asrEngine) {
  if (!selectedWord) return;

  const target = selectedWord.word;

  let targetPhonemes, spokenPhonemes;
  try {
    [targetPhonemes, spokenPhonemes] = await Promise.all([
      phonemize(target),
      phonemize(spokenText)
    ]);
  } catch (e) {
    showToast('⚠️ Could not phonemize for scoring: ' + e.message);
    return;
  }

  if (!targetPhonemes.length) {
    showToast('⚠️ No reference phonemes for "' + target + '".');
    return;
  }
  if (!spokenPhonemes.length) {
    // No phonemes for the spoken input (noise/unpronounceable). Score as 0
    // with the standard attempt record so history/reports remain well-formed.
    const Sacc = 0;
    const werResult = { wer: 100, subs: 0, dels: target.length, ins: 0, matches: 0 };
    const perResult = { per: 100, subs: 0, dels: targetPhonemes.length, ins: 0, matches: 0 };
    const engine = asrEngine || ASR_ENGINE.SIMULATED;
    const attempt = {
      targetWord: target,
      spokenText: spokenText,
      targetPhonemes,
      spokenPhonemes: [],
      accuracy: 0,
      wer: werResult.wer,
      per: perResult.per,
      subs: 0,
      dels: targetPhonemes.length,
      ins: 0,
      asrEngine: engine,
      feedback: feedbackBandFor(0),
      timestamp: Date.now(),
      alignment: []
    };
    sessionHistory.push(attempt);
    saveSessionHistory();
    renderResults(attempt);
    renderFeedback(0);
    $('resultPanel').style.display = 'block';
    updateHistoryUI();
    return;
  }

  // WER
  const werResult = computeWER(target, spokenText);
  // PER
  const perResult = computePER(targetPhonemes, spokenPhonemes);

  // Pronunciation accuracy score (Sacc formula from manuscript)
  const Np = targetPhonemes.length;
  const Sp = perResult.subs;
  const Dp = perResult.dels;
  const Ip = perResult.ins;
  const Sacc = Math.max(0, ((Np - (Sp + Dp + Ip)) / Np) * 100);

  // Display results
  $('resultTarget').textContent = target;
  $('resultSpoken').textContent = spokenText.toLowerCase();
  // Key the badge off the engine that actually produced THIS attempt, not the
  // global demo flag: a single simulated attempt can happen without the app
  // being in demo mode, and that must still be disclosed.
  const engine = asrEngine || ASR_ENGINE.SIMULATED;
  $('demoModeBadge').style.display = (demoMode || engine === ASR_ENGINE.SIMULATED) ? 'block' : 'none';

  // Always disclose which engine produced the transcript. Without this a
  // simulated attempt is indistinguishable from a real measurement.
  const engineNote = $('asrEngineNote');
  if (engine === ASR_ENGINE.SIMULATED) {
    engineNote.textContent = 'Simulated attempt - no speech transcriber was available, so this score is not a measurement.';
    engineNote.className = 'asr-engine-note simulated';
  } else if (engine === ASR_ENGINE.WEB_SPEECH) {
    engineNote.textContent = 'Transcribed by the browser (Web Speech API), not a child-speech acoustic model.';
    engineNote.className = 'asr-engine-note';
  } else {
    engineNote.textContent = 'Transcribed by the EchoVoice backend acoustic model.';
    engineNote.className = 'asr-engine-note';
  }
  engineNote.style.display = 'block';
  resultPanel.style.display = 'block';

  // Metrics grid
  const colorClass = v => v <= 15 ? 'good' : v <= 40 ? 'warn' : 'bad';
  const accColor = v => v >= 85 ? 'good' : v >= 60 ? 'warn' : 'bad';

  $('metricsGrid').innerHTML = `
    <div class="metric-card">
      <div class="metric-icon">🎯</div>
      <div class="metric-value ${accColor(Sacc)}">${Sacc.toFixed(1)}%</div>
      <div class="metric-label">Accuracy (S<sub>acc</sub>)</div>
    </div>
    <div class="metric-card">
      <div class="metric-icon">🔤</div>
      <div class="metric-value ${colorClass(werResult.wer)}">${werResult.wer.toFixed(1)}%</div>
      <div class="metric-label">Word Error Rate</div>
    </div>
    <div class="metric-card">
      <div class="metric-icon">🔬</div>
      <div class="metric-value ${colorClass(perResult.per)}">${perResult.per.toFixed(1)}%</div>
      <div class="metric-label">Phoneme Error Rate</div>
    </div>
    <div class="metric-card">
      <div class="metric-icon">🔁</div>
      <div class="metric-value">${Sp}</div>
      <div class="metric-label">Substitutions</div>
    </div>
    <div class="metric-card">
      <div class="metric-icon">❌</div>
      <div class="metric-value">${Dp}</div>
      <div class="metric-label">Deletions</div>
    </div>
    <div class="metric-card">
      <div class="metric-icon">➕</div>
      <div class="metric-value">${Ip}</div>
      <div class="metric-label">Insertions</div>
    </div>
  `;

  // Phoneme alignment chips
  const phonemeRow = $('phonemeRow');
  phonemeRow.innerHTML = '';
  perResult.alignment.forEach(a => {
    const chip = document.createElement('span');
    chip.className = 'phoneme-chip ' + a.type;
    if (a.type === 'correct') chip.textContent = a.ref;
    else if (a.type === 'substitution') chip.textContent = `${a.ref}→${a.hyp}`;
    else if (a.type === 'deletion') chip.textContent = `${a.ref} ✕`;
    else if (a.type === 'insertion') chip.textContent = `+${a.hyp}`;
    chip.title = a.type.charAt(0).toUpperCase() + a.type.slice(1);
    phonemeRow.appendChild(chip);
  });

  resultPanel.scrollIntoView({ behavior: 'smooth', block: 'center' });

  // Save to history
  const entry = {
    id: Date.now(),
    timestamp: new Date().toISOString(),
    childName: $('childName').value || 'Unknown',
    childAge: $('childAge').value || '—',
    targetWord: target,
    targetIpa: selectedWord.ipa,
    spokenText: spokenText.toLowerCase(),
    targetPhonemes: targetPhonemes,
    spokenPhonemes: spokenPhonemes,
    wer: werResult.wer,
    per: perResult.per,
    accuracy: Sacc,
    subs: Sp,
    dels: Dp,
    ins: Ip,
    alignment: perResult.alignment,
    asrEngine: asrEngine || ASR_ENGINE.SIMULATED
  };
  sessionHistory.push(entry);
  localStorage.setItem(historyKey(currentUser()), JSON.stringify(sessionHistory));

  // Feedback System: banded encouragement + star animation / replay prompt
  renderFeedback(Sacc);

  renderWordGrid(); // update tested state
  if ($('section-profile').classList.contains('active')) renderProfilePage();
}

// ===== History Rendering =====
function renderHistory() {
  const content = $('historyContent');
  if (sessionHistory.length === 0) {
    content.innerHTML = '<p style="color:var(--text-muted); font-style:italic;">No attempts recorded yet.</p>';
    return;
  }
  let html = `<table class="session-table">
    <thead><tr>
      <th>Word</th><th>Spoken</th><th>WER</th><th>PER</th><th>Accuracy</th><th>S/D/I</th><th>Time</th>
    </tr></thead><tbody>`;

  [...sessionHistory].reverse().forEach(h => {
    const time = new Date(h.timestamp).toLocaleTimeString();
    const accColor = h.accuracy >= 85 ? 'var(--green)' : h.accuracy >= 60 ? 'var(--orange)' : 'var(--red)';
    html += `<tr>
      <td><strong>${h.targetWord}</strong></td>
      <td>${h.spokenText}</td>
      <td>${h.wer.toFixed(1)}%</td>
      <td>${h.per.toFixed(1)}%</td>
      <td style="color:${accColor}; font-weight:700;">${h.accuracy.toFixed(1)}%</td>
      <td>${h.subs}/${h.dels}/${h.ins}</td>
      <td style="font-size:.78rem; color:var(--text-muted);">${time}</td>
    </tr>`;
  });
  html += '</tbody></table>';
  content.innerHTML = html;
}

$('clearHistoryBtn').addEventListener('click', () => {
  const user = currentUser();
  if (confirm('Clear all session history?' + (user ? ` for "${user}"` : '') + '?')) {
    sessionHistory = [];
    localStorage.removeItem(historyKey(user));
    renderHistory();
    updateReportSummary();
    showToast('🗑️ History cleared');
  }
});

// ===== Report Summary =====
function updateReportSummary() {
  const h = sessionHistory;
  $('repTotalAttempts').textContent = h.length;
  const uniqueWords = new Set(h.map(e => e.targetWord));
  $('repUniqueWords').textContent = uniqueWords.size;

  if (h.length > 0) {
    const avgWER = h.reduce((s,e) => s + e.wer, 0) / h.length;
    const avgPER = h.reduce((s,e) => s + e.per, 0) / h.length;
    const avgAcc = h.reduce((s,e) => s + e.accuracy, 0) / h.length;
    $('repAvgWER').textContent = avgWER.toFixed(1) + '%';
    $('repAvgPER').textContent = avgPER.toFixed(1) + '%';
    $('repAvgAccuracy').textContent = avgAcc.toFixed(1) + '%';

    // Best word
    const wordAccs = {};
    h.forEach(e => {
      if (!wordAccs[e.targetWord]) wordAccs[e.targetWord] = [];
      wordAccs[e.targetWord].push(e.accuracy);
    });
    let bestWord = '—', bestAcc = -1;
    for (const [w, accs] of Object.entries(wordAccs)) {
      const avg = accs.reduce((a,b)=>a+b,0)/accs.length;
      if (avg > bestAcc) { bestAcc = avg; bestWord = w; }
    }
    $('repBestWord').textContent = bestWord;
  } else {
    $('repAvgWER').textContent = '—';
    $('repAvgPER').textContent = '—';
    $('repAvgAccuracy').textContent = '—';
    $('repBestWord').textContent = '—';
  }
}

// ===== Profile Page =====
const MASTERY_THRESHOLD = 80;

function wordCategoryMap() {
  const map = {};
  Object.keys(WORD_BANK).forEach(cat => {
    WORD_BANK[cat].forEach(w => { map[w.word.toLowerCase()] = cat; });
  });
  return map;
}

function renderProfilePage() {
  const h = sessionHistory;
  const name = $('childName').value.trim();
  const age = $('childAge').value.trim();
  const dateVal = $('sessionDate').value;
  const catMap = wordCategoryMap();

  // Status header
  const heroName = $('profileHeroName');
  const heroMeta = $('profileHeroMeta');
  if (name) {
    heroName.textContent = name;
    const bits = [];
    if (age) bits.push('Age ' + age);
    if (dateVal) bits.push('Session ' + dateVal);
    heroMeta.textContent = bits.length ? bits.join(' • ') : 'Profile saved — add an age to complete it.';
  } else {
    heroName.textContent = 'No child profile yet';
    heroMeta.textContent = 'Save a profile below to start tracking progress.';
  }

  // Per-word averages and mastery
  const perWord = {};
  h.forEach(e => {
    const key = (e.targetWord || '').toLowerCase();
    if (!key) return;
    if (!perWord[key]) perWord[key] = [];
    perWord[key].push(e.accuracy);
  });
  const wordAvg = {};
  Object.keys(perWord).forEach(k => {
    wordAvg[k] = perWord[k].reduce((a, b) => a + b, 0) / perWord[k].length;
  });

  const totalWords = Object.keys(WORD_BANK).reduce((s, c) => s + WORD_BANK[c].length, 0);
  const attempted = Object.keys(wordAvg).length;
  const mastered = Object.values(wordAvg).filter(a => a >= MASTERY_THRESHOLD).length;
  const masteryPct = totalWords ? Math.round((mastered / totalWords) * 100) : 0;

  const ring = $('profileHeroRing');
  ring.style.setProperty('--mastery', masteryPct);
  $('profileMasteryPct').textContent = masteryPct + '%';
  $('profileMasteryFill').style.width = masteryPct + '%';
  $('profileMasteryBar').setAttribute('aria-valuenow', String(masteryPct));
  $('profileProgressCaption').textContent =
    mastered + ' of ' + totalWords + ' words mastered (accuracy ≥ ' + MASTERY_THRESHOLD + '%)';

  // Summary stats
  $('pfAttempts').textContent = h.length;
  $('pfUniqueWords').textContent = attempted;
  $('pfMastered').textContent = mastered;
  if (h.length > 0) {
    const avgWER = h.reduce((s, e) => s + e.wer, 0) / h.length;
    const avgPER = h.reduce((s, e) => s + e.per, 0) / h.length;
    const avgAcc = h.reduce((s, e) => s + e.accuracy, 0) / h.length;
    $('pfAvgAccuracy').textContent = avgAcc.toFixed(1) + '%';
    $('pfAvgWER').textContent = avgWER.toFixed(1) + '%';
    $('pfAvgPER').textContent = avgPER.toFixed(1) + '%';
  } else {
    $('pfAvgAccuracy').textContent = '—';
    $('pfAvgWER').textContent = '—';
    $('pfAvgPER').textContent = '—';
  }

  // Progress by category
  const list = $('profileCategoryList');
  list.innerHTML = '';
  if (h.length === 0) {
    const p = document.createElement('p');
    p.className = 'profile-empty';
    p.textContent = 'No attempts yet — progress bars appear after the first scored attempt.';
    list.appendChild(p);
    return;
  }
  Object.keys(WORD_BANK).forEach(cat => {
    const words = WORD_BANK[cat];
    const keys = words.map(w => w.word.toLowerCase());
    const seen = keys.filter(k => wordAvg[k] !== undefined);
    const catMastered = seen.filter(k => wordAvg[k] >= MASTERY_THRESHOLD).length;
    const pct = words.length ? Math.round((catMastered / words.length) * 100) : 0;
    const avg = seen.length
      ? seen.reduce((s, k) => s + wordAvg[k], 0) / seen.length
      : null;

    const row = document.createElement('div');
    row.className = 'profile-cat-row';

    const head = document.createElement('div');
    head.className = 'profile-cat-head';
    const meta = CATEGORY_META[cat] || { icon: '📚' };
    const label = document.createElement('span');
    label.textContent = meta.icon + ' ' + cat;
    const stat = document.createElement('span');
    stat.className = 'profile-cat-meta';
    stat.textContent = catMastered + '/' + words.length + ' mastered'
      + (avg !== null ? ' • avg ' + avg.toFixed(0) + '%' : ' • not practiced');
    head.appendChild(label);
    head.appendChild(stat);

    const track = document.createElement('div');
    track.className = 'profile-cat-track';
    const fill = document.createElement('div');
    fill.className = 'profile-cat-fill';
    fill.style.width = pct + '%';
    fill.style.background = 'linear-gradient(90deg, ' + meta.from + ', ' + meta.to + ')';
    track.appendChild(fill);

    row.appendChild(head);
    row.appendChild(track);
    list.appendChild(row);
  });
}

// ===== Feedback System =====
// Age-appropriate encouragement banded on pronunciation accuracy (Sacc).
// 90-100% earns a star animation; below 30% invites practice together with a
// replay prompt so the child hears the target again before retrying.
const FEEDBACK_BANDS = [
  {
    min: 90, band: 'excellent', stars: 5,
    message: 'Very Good!',
    sub: acc => `${acc.toFixed(0)}% — that sounded almost perfect!`,
  },
  {
    min: 70, band: 'great', stars: 4,
    message: 'Great Job!',
    sub: acc => `${acc.toFixed(0)}% — you are getting very close.`,
  },
  {
    min: 50, band: 'good', stars: 3,
    message: 'Good Try!',
    sub: acc => `${acc.toFixed(0)}% — keep going, you are learning fast!`,
  },
  {
    min: 30, band: 'keepgoing', stars: 2,
    message: 'Keep Going!',
    sub: acc => `${acc.toFixed(0)}% — listen once more, then try again.`,
  },
  {
    min: 0, band: 'practice', stars: 1,
    message: "Let's Practice Together!",
    sub: acc => `${acc.toFixed(0)}% — let's listen to the word and say it together.`,
  },
];

function feedbackBandFor(accuracy) {
  return FEEDBACK_BANDS.find(b => accuracy >= b.min) || FEEDBACK_BANDS[FEEDBACK_BANDS.length - 1];
}

function saveSessionHistory(){ try{ var k='echovoice_history_'+(localStorage.getItem('echovoice_session')||'default'); localStorage.setItem(k, JSON.stringify(sessionHistory||[])); }catch(e){} }

function renderFeedback(accuracy) {
  const fb = feedbackBandFor(accuracy);
  const panel = $('feedbackPanel');
  const starRow = $('feedbackStars');

  starRow.innerHTML = '';
  for (let i = 0; i < fb.stars; i++) {
    const s = document.createElement('span');
    s.className = 'feedback-star';
    s.textContent = '\u2b50';
    starRow.appendChild(s);
  }

  $('feedbackMessage').textContent = fb.message;
  $('feedbackSub').textContent = fb.sub(accuracy);

  // The replay prompt is the point of the lowest band: listen, then retry.
  $('feedbackReplayBtn').style.display = fb.band === 'practice' ? '' : 'none';
  $('feedbackTryBtn').style.display = accuracy < 90 ? '' : 'none';

  panel.className = 'feedback-panel band-' + fb.band;
  panel.style.display = 'block';
  // Restart the pop-in animation on repeat attempts.
  panel.style.animation = 'none';
  void panel.offsetWidth;
  panel.style.animation = '';

  showToast(fb.message);
  return fb;
}

// Replay prompt + retry affordances
$('feedbackReplayBtn').addEventListener('click', () => {
  if (selectedWord) {
    speakWord(selectedWord.word);
    $('activeWordPanel').scrollIntoView({ behavior: 'smooth', block: 'center' });
  } else {
    showToast('👆 Pick a word first, then listen again.');
  }
});
$('feedbackTryBtn').addEventListener('click', () => {
  $('micSection').scrollIntoView({ behavior: 'smooth', block: 'center' });
  showToast('🎙️ Tap the microphone and say it again!');
});

// ===== Report Generation =====
// Two downloadable PDFs plus a CSV dump:
//   * Child Progress Report  - stars, streaks, badges, zero technical metrics
//   * Clinician Report       - phoneme error matrix, error-pattern trends, metrics
$('genChildPdfBtn').addEventListener('click', generateChildReportPDF);
$('genClinicianPdfBtn').addEventListener('click', generateClinicianReportPDF);
$('exportCsvBtn').addEventListener('click', exportSessionCsv);

const REPORT_COLORS = {
  purple: [108, 92, 231],
  dark: [45, 52, 54],
  gray: [99, 110, 114],
  green: [0, 184, 148],
  red: [214, 48, 49],
  orange: [225, 112, 85],
  gold: [244, 208, 63],
  pink: [255, 154, 158],
  white: [255, 255, 255],
};

function aggregateStats(h) {
  const avg = k => h.reduce((s, e) => s + (e[k] || 0), 0) / h.length;
  const perWord = {};
  h.forEach(e => {
    const w = (e.targetWord || '').toLowerCase();
    if (!w) return;
    (perWord[w] = perWord[w] || { word: e.targetWord, ipa: e.targetIpa, accs: [] }).accs.push(e.accuracy);
  });
  const words = Object.values(perWord).map(d => {
    const avgAcc = d.accs.reduce((a, b) => a + b, 0) / d.accs.length;
    return { word: d.word, ipa: d.ipa, attempts: d.accs.length, avgAcc };
  });
  return {
    attempts: h.length,
    avgWER: avg('wer'),
    avgPER: avg('per'),
    avgAcc: avg('accuracy'),
    totalSubs: h.reduce((s, e) => s + e.subs, 0),
    totalDels: h.reduce((s, e) => s + e.dels, 0),
    totalIns: h.reduce((s, e) => s + e.ins, 0),
    uniqueWords: new Set(h.map(e => e.targetWord)).size,
    words,
  };
}

// Star rating out of 5 from a 0-100 accuracy score.
function starRating(accuracy) {
  if (accuracy >= 95) return 5;
  if (accuracy >= 85) return 4;
  if (accuracy >= 70) return 3;
  if (accuracy >= 50) return 2;
  return 1;
}

// ---------- PDF vector art ----------
// jsPDF's built-in fonts are WinAnsi-encoded, so emoji and symbols outside
// Latin-1 (star, trophy, check marks) render as garbage. Everything decorative
// in the reports is drawn as vector paths instead of text glyphs.
// jsPDF's lines() moves to (x, y) and then applies every delta relative to the
// running point, so the anchor must be the first vertex and the deltas must be
// consecutive differences. Passing a separate centre would add a stray vertex.
function pdfPoly(doc, pts, style) {
  const deltas = pts.slice(1).map((p, i) => [p[0] - pts[i][0], p[1] - pts[i][1]]);
  doc.lines(deltas, pts[0][0], pts[0][1], [1, 1], style, true);
}

function pdfStar(doc, cx, cy, outer, inner, color) {
  const pts = [];
  for (let i = 0; i < 10; i++) {
    const r = i % 2 === 0 ? outer : inner;
    const a = (Math.PI / 5) * i - Math.PI / 2;
    pts.push([cx + r * Math.cos(a), cy + r * Math.sin(a)]);
  }
  doc.setFillColor(...color);
  pdfPoly(doc, pts, 'F');
}

function pdfStars(doc, x, y, filled, outer) {
  const step = outer * 2.4;
  for (let i = 0; i < 5; i++) {
    pdfStar(doc, x + outer + i * step, y, outer, outer * 0.45,
      i < filled ? [244, 208, 63] : [226, 226, 234]);
  }
  return 5 * step;
}

// Simple, distinct marks so each badge is recognisable without an icon font.
function pdfBadgeMark(doc, shape, cx, cy, r, color) {
  doc.setFillColor(...color);
  doc.setDrawColor(...color);
  doc.setLineWidth(0.4);
  switch (shape) {
    case 'star':
      pdfStar(doc, cx, cy, r, r * 0.45, color);
      break;
    case 'target':
      doc.circle(cx, cy, r, 'F');
      doc.setFillColor(255, 255, 255);
      doc.circle(cx, cy, r * 0.55, 'F');
      doc.setFillColor(...color);
      doc.circle(cx, cy, r * 0.25, 'F');
      break;
    case 'bolt':
      pdfPoly(doc, [
        [cx + r * 0.25, cy - r], [cx - r * 0.7, cy + r * 0.12],
        [cx - r * 0.05, cy + r * 0.12], [cx - r * 0.3, cy + r],
        [cx + r * 0.7, cy - r * 0.14], [cx + r * 0.05, cy - r * 0.14],
      ], 'F');
      break;
    case 'bars':
      doc.rect(cx - r, cy - r * 0.2, r * 0.6, r * 1.2, 'F');
      doc.rect(cx - r * 0.3, cy - r * 0.6, r * 0.6, r * 1.6, 'F');
      doc.rect(cx + r * 0.4, cy - r, r * 0.6, r * 2, 'F');
      break;
    case 'cup':
      pdfPoly(doc, [
        [cx - r * 0.75, cy - r * 0.8], [cx + r * 0.75, cy - r * 0.8],
        [cx + r * 0.45, cy + r * 0.25], [cx - r * 0.45, cy + r * 0.25],
      ], 'F');
      doc.rect(cx - r * 0.12, cy + r * 0.25, r * 0.24, r * 0.45, 'F');
      doc.rect(cx - r * 0.6, cy + r * 0.7, r * 1.2, r * 0.28, 'F');
      break;
    case 'book':
      doc.roundedRect(cx - r, cy - r * 0.8, r * 2, r * 1.6, 1, 1, 'F');
      doc.setFillColor(255, 255, 255);
      doc.rect(cx - r * 0.12, cy - r * 0.8, r * 0.24, r * 1.6, 'F');
      break;
    case 'calendar':
      doc.roundedRect(cx - r, cy - r * 0.75, r * 2, r * 1.6, 1, 1, 'F');
      doc.setFillColor(255, 255, 255);
      doc.rect(cx - r, cy - r * 0.75, r * 2, r * 0.45, 'F');
      break;
    default:
      doc.circle(cx, cy, r, 'F');
  }
}

// Consecutive mastered words = best run of >= MASTERY_THRESHOLD attempts in order.
function computeStreak(history) {
  let best = 0, run = 0;
  history.forEach(e => {
    if (e.accuracy >= MASTERY_THRESHOLD) { run++; best = Math.max(best, run); }
    else run = 0;
  });
  return best;
}

// Badges earned, derived only from attempt history (no technical metrics shown).
function earnedBadges(h, stats) {
  const badges = [];
  const mastered = stats.words.filter(w => w.avgAcc >= MASTERY_THRESHOLD).length;
  const perfect = h.filter(e => e.accuracy >= 99.5).length;
  const streak = computeStreak(h);
  const days = new Set(h.map(e => String(e.timestamp).slice(0, 10))).size;

  if (h.length >= 1) badges.push({ shape: 'target', color: [244, 208, 63], name: 'First Try', desc: 'Practised your very first word' });
  if (stats.attempts >= 10) badges.push({ shape: 'book', color: [96, 165, 250], name: 'Bookworm', desc: '10 attempts completed' });
  if (stats.attempts >= 25) badges.push({ shape: 'bolt', color: [249, 168, 37], name: 'Practice Champ', desc: '25 attempts completed' });
  if (streak >= 3) badges.push({ shape: 'bolt', color: [239, 68, 68], name: 'On Fire', desc: `${streak} great tries in a row` });
  if (streak >= 5) badges.push({ shape: 'bars', color: [139, 92, 246], name: 'Streak Master', desc: `${streak} great tries in a row` });
  if (stats.uniqueWords >= 10) badges.push({ shape: 'calendar', color: [16, 185, 129], name: 'Word Explorer', desc: 'Tried 10 different words' });
  if (stats.uniqueWords >= 25) badges.push({ shape: 'book', color: [236, 72, 153], name: 'Curious Mind', desc: 'Tried 25 different words' });
  if (stats.uniqueWords >= 50) badges.push({ shape: 'cup', color: [180, 130, 0], name: 'Word Champion', desc: 'Tried every word in the bank' });
  if (mastered >= 1) badges.push({ shape: 'star', color: [244, 208, 63], name: 'Star Getter', desc: 'Mastered your first word' });
  if (mastered >= 5) badges.push({ shape: 'star', color: [59, 130, 246], name: 'Rising Star', desc: 'Mastered 5 words' });
  if (mastered >= 15) badges.push({ shape: 'star', color: [168, 85, 247], name: 'Superstar', desc: 'Mastered 15 words' });
  if (mastered >= stats.words.length && stats.words.length > 0) badges.push({ shape: 'cup', color: [16, 185, 129], name: 'Perfect Session', desc: 'Mastered every word you tried' });
  if (perfect >= 5) badges.push({ shape: 'target', color: [14, 165, 233], name: 'Sharp Ears', desc: '5 perfect pronunciations' });
  if (days >= 3) badges.push({ shape: 'calendar', color: [100, 116, 139], name: 'Regular', desc: 'Practised on 3 different days' });
  return badges;
}

function reportIdentity() {
  return {
    childName: $('childName').value || 'Not specified',
    childAge: $('childAge').value || 'Not specified',
    sessDate: $('sessionDate').value || new Date().toISOString().slice(0, 10),
    accountName: currentUser() || 'guest',
  };
}

function requireHistory() {
  if (sessionHistory.length === 0) {
    showToast('⚠️ No data to generate report!');
    return false;
  }
  return true;
}

// ---------- Child Progress Report ----------
// Deliberately free of PER/WER/Sacc language: stars, streaks and badges only.
function generateChildReportPDF() {
  if (!requireHistory()) return;
  const { jsPDF } = window.jspdf;
  const doc = new jsPDF('p', 'mm', 'a4');
  const pageW = doc.internal.pageSize.getWidth();
  const pageH = doc.internal.pageSize.getHeight();
  const margin = 18;
  const C = REPORT_COLORS;
  const id = reportIdentity();
  const stats = aggregateStats(sessionHistory);
  const badges = earnedBadges(sessionHistory, stats);
  const streak = computeStreak(sessionHistory);

  // Playful header
  doc.setFillColor(255, 214, 224);
  doc.rect(0, 0, pageW, 52, 'F');
  doc.setFillColor(255, 240, 150);
  doc.circle(pageW - 26, 14, 13, 'F');
  doc.setTextColor(...C.dark);
  doc.setFontSize(24);
  doc.setFont('helvetica', 'bold');
  doc.text('My Progress Report', margin, 22);
  doc.setFontSize(11);
  doc.setFont('helvetica', 'normal');
  doc.text(id.childName + (id.childAge !== 'Not specified' ? ', age ' + id.childAge : ''), margin, 31);
  doc.setFontSize(9);
  doc.text('EchoVoice \u2022 ' + id.sessDate, margin, 39);

  let y = 62;

  // Big friendly summary
  doc.setFillColor(255, 255, 255);
  doc.setDrawColor(...C.pink);
  doc.setLineWidth(1);
  doc.roundedRect(margin, y - 8, pageW - 2 * margin, 34, 5, 5, 'FD');
  const avgStars = starRating(stats.avgAcc);
  doc.setFontSize(11);
  doc.setFont('helvetica', 'bold');
  doc.setTextColor(...C.dark);
  doc.text('You practised ' + stats.attempts + ' time' + (stats.attempts === 1 ? '' : 's') + ' and tried '
    + stats.uniqueWords + ' different word' + (stats.uniqueWords === 1 ? '' : 's') + '!', margin + 8, y + 2);
  const starSpan = pdfStars(doc, margin + 8, y + 15, avgStars, 3);
  doc.setFontSize(10);
  doc.setFont('helvetica', 'normal');
  doc.setTextColor(...C.gray);
  doc.text('Your best streak: ' + streak + ' great ' + (streak === 1 ? 'try' : 'tries') + ' in a row!', margin + 8 + starSpan + 4, y + 18);
  y += 38;

  // Star ratings per word
  doc.setFontSize(13);
  doc.setFont('helvetica', 'bold');
  doc.setTextColor(...C.dark);
  doc.text('My Words', margin + 9, y);
  pdfStar(doc, margin + 4, y - 1.6, 3.4, 1.5, [244, 208, 63]);
  y += 8;

  const sorted = stats.words.slice().sort((a, b) => b.avgAcc - a.avgAcc || a.word.localeCompare(b.word));
  sorted.forEach(w => {
    if (y > pageH - 24) { doc.addPage(); y = 24; }
    const stars = starRating(w.avgAcc);
    doc.setFillColor(250, 250, 255);
    doc.setDrawColor(228, 228, 240);
    doc.setLineWidth(0.3);
    doc.roundedRect(margin, y - 5, pageW - 2 * margin, 13, 3, 3, 'FD');
    doc.setFontSize(11);
    doc.setFont('helvetica', 'bold');
    doc.setTextColor(...C.dark);
    doc.text(w.word, margin + 5, y + 4);
    doc.setFontSize(8.5);
    doc.setFont('helvetica', 'normal');
    doc.setTextColor(...C.gray);
    doc.text('tried ' + w.attempts + 'x', margin + 46, y + 4);
    pdfStars(doc, pageW - margin - 45, y + 1, stars, 2.1);
    y += 15;
  });

  // Badges
  y += 6;
  if (y > pageH - 40) { doc.addPage(); y = 24; }
  doc.setFontSize(13);
  doc.setFont('helvetica', 'bold');
  doc.setTextColor(...C.dark);
  doc.text('My Badges', margin + 9, y);
  pdfBadgeMark(doc, 'cup', margin + 4, y - 1.6, 3.4, [180, 130, 0]);
  y += 8;

  if (badges.length === 0) {
    doc.setFontSize(10);
    doc.setFont('helvetica', 'normal');
    doc.setTextColor(...C.gray);
    doc.text('Keep practising to earn your first badge!', margin, y);
    y += 8;
  } else {
    badges.forEach(b => {
      if (y > pageH - 24) { doc.addPage(); y = 24; }
      doc.setFillColor(255, 250, 230);
      doc.setDrawColor(244, 208, 63);
      doc.setLineWidth(0.4);
      doc.roundedRect(margin, y - 5, pageW - 2 * margin, 13, 3, 3, 'FD');
doc.setFontSize(9);
    pdfBadgeMark(doc, b.shape, margin + 9, y + 1, 3, b.color);
    doc.setFontSize(11);
    doc.setFont('helvetica', 'bold');
    doc.setTextColor(...C.dark);
    doc.text(b.name, margin + 15, y + 4);
      doc.setFont('helvetica', 'normal');
      doc.setFontSize(8.5);
      doc.setTextColor(...C.gray);
      doc.text(b.desc, margin + 60, y + 4);
      y += 15;
    });
  }

  // Footer
  doc.setFontSize(8);
  doc.setTextColor(...C.gray);
  doc.text('Made with EchoVoice \u2014 DMMMSU South La Union Campus', margin, pageH - 12);
  doc.text(new Date().toLocaleDateString(), pageW - margin, pageH - 12, { align: 'right' });

  doc.save('EchoVoice_Child_Progress_' + id.childName.replace(/\s+/g, '_') + '_' + id.sessDate + '.pdf');
  showToast('📥 Child Progress Report downloaded!');
}

// ---------- CSV export ----------
function csvEscape(v) {
  const s = v === null || v === undefined ? '' : String(v);
  return /[",\n]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s;
}

function exportSessionCsv() {
  if (!requireHistory()) return;
  const id = reportIdentity();
  const header = [
    'timestamp', 'child_name', 'child_age', 'target_word', 'target_ipa',
    'spoken_text', 'accuracy_pct', 'wer_pct', 'per_pct',
    'substitutions', 'deletions', 'insertions',
    'target_phonemes', 'spoken_phonemes', 'alignment', 'asr_engine',
  ];
  const rows = sessionHistory.map(e => [
    e.timestamp, e.childName, e.childAge, e.targetWord, e.targetIpa,
    e.spokenText,
    Number(e.accuracy).toFixed(2), Number(e.wer).toFixed(2), Number(e.per).toFixed(2),
    e.subs, e.dels, e.ins,
    (e.targetPhonemes || []).join(' '), (e.spokenPhonemes || []).join(' '),
    (e.alignment || []).map(a =>
      a.type === 'correct' ? a.ref :
      a.type === 'substitution' ? a.ref + '>' + a.hyp :
      a.type === 'deletion' ? a.ref + '>X' : 'X>' + a.hyp
    ).join(' '),
    e.asrEngine || ASR_ENGINE.SIMULATED,
  ]);

  const meta = [
    ['# EchoVoice session data export'],
    ['# account', id.accountName],
    ['# child', id.childName],
    ['# age', id.childAge],
    ['# session_date', id.sessDate],
    ['# exported', new Date().toISOString()],
    ['# attempts', sessionHistory.length],
    ['# asr_engines_used', Array.from(new Set(sessionHistory.map(e => e.asrEngine || ASR_ENGINE.SIMULATED))).join(' + ')],
    [],
  ];
  const csv = meta.map(r => r.map(csvEscape).join(',')).concat([header.map(csvEscape).join(',')])
    .concat(rows.map(r => r.map(csvEscape).join(','))).join('\r\n');

  const blob = new Blob(['\ufeff' + csv], { type: 'text/csv;charset=utf-8;' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = 'EchoVoice_Session_' + id.childName.replace(/\s+/g, '_') + '_' + id.sessDate + '.csv';
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  setTimeout(() => URL.revokeObjectURL(url), 1000);
  showToast('📊 CSV exported!');
}

// ---------- Clinician Report ----------
// The technical counterpart to the Child Progress Report: aggregate metrics,
// per-word summary, phoneme error matrix, error-pattern trends, attempt log.
function generateClinicianReportPDF() {
  if (!requireHistory()) return;

  const { jsPDF } = window.jspdf;
  const doc = new jsPDF('p', 'mm', 'a4');
  const pageW = doc.internal.pageSize.getWidth();
  const margin = 18;
  let y = 20;

  // Colors
  const purple = [108,92,231];
  const dark = [45,52,54];
  const gray = [99,110,114];
  const green = [0,184,148];
  const red = [214,48,49];
  const orange = [225,112,85];

  // Header
  doc.setFillColor(...purple);
  doc.rect(0, 0, pageW, 42, 'F');
  doc.setTextColor(255,255,255);
  doc.setFontSize(22);
  doc.setFont('helvetica','bold');
  doc.text('EchoVoice', pageW/2, 16, { align: 'center' });
  doc.setFontSize(9);
  doc.setFont('helvetica','normal');
  doc.text('A Web-Based Pronunciation Assessment for Speech Therapy', pageW/2, 24, { align: 'center' });
  doc.setFontSize(7.5);
  doc.text('Nievera, K.D. • Cerezo, K.A. • Doctolero, M.J. • Gonzales, R.Jr. • Paglingayen, J.', pageW/2, 30, { align: 'center' });
  doc.text('DMMMSU – South La Union Campus • College of Computer Science • October 2026', pageW/2, 35, { align: 'center' });
  y = 50;

  // Child info
  doc.setTextColor(...dark);
  doc.setFontSize(13);
  doc.setFont('helvetica','bold');
  doc.text('Clinician Assessment Report', margin, y);
  y += 8;
  doc.setFontSize(9);
  doc.setFont('helvetica','normal');
  doc.setTextColor(...gray);
  const childName = $('childName').value || 'Not specified';
  const childAge = $('childAge').value || 'Not specified';
  const sessDate = $('sessionDate').value || new Date().toISOString().slice(0,10);
  const accountName = currentUser() || 'guest';
  doc.text(`Account: ${accountName}`, margin, y);
  y += 4;
  doc.text(`Child: ${childName}     Age: ${childAge}     Session Date: ${sessDate}`, margin, y);
  y += 4;
  doc.text(`Report Generated: ${new Date().toLocaleString()}     Total Attempts: ${sessionHistory.length}`, margin, y);
  y += 10;

  // Divider
  doc.setDrawColor(...purple);
  doc.setLineWidth(0.5);
  doc.line(margin, y, pageW - margin, y);
  y += 8;

  // Summary Statistics
  const h = sessionHistory;
  const avgWER = h.reduce((s,e) => s + e.wer, 0) / h.length;
  const avgPER = h.reduce((s,e) => s + e.per, 0) / h.length;
  const avgAcc = h.reduce((s,e) => s + e.accuracy, 0) / h.length;
  const totalSubs = h.reduce((s,e) => s + e.subs, 0);
  const totalDels = h.reduce((s,e) => s + e.dels, 0);
  const totalIns = h.reduce((s,e) => s + e.ins, 0);
  const uniqueWords = new Set(h.map(e => e.targetWord));

  doc.setFontSize(11);
  doc.setFont('helvetica','bold');
  doc.setTextColor(...dark);
  doc.text('Aggregate Performance Metrics', margin, y);
  y += 8;

  // Summary boxes
  const boxW = (pageW - 2*margin - 2*8) / 3;
  const drawMetricBox = (x, yPos, label, value, color) => {
    doc.setFillColor(245,245,255);
    doc.roundedRect(x, yPos, boxW, 28, 3, 3, 'F');
    doc.setFontSize(16);
    doc.setFont('helvetica','bold');
    doc.setTextColor(...color);
    doc.text(value, x + boxW/2, yPos + 13, { align: 'center' });
    doc.setFontSize(7.5);
    doc.setFont('helvetica','normal');
    doc.setTextColor(...gray);
    doc.text(label, x + boxW/2, yPos + 22, { align: 'center' });
  };

  drawMetricBox(margin, y, 'Avg Accuracy (Sacc)', avgAcc.toFixed(1) + '%', avgAcc >= 85 ? green : avgAcc >= 60 ? orange : red);
  drawMetricBox(margin + boxW + 8, y, 'Avg Word Error Rate (WER)', avgWER.toFixed(1) + '%', avgWER <= 15 ? green : avgWER <= 40 ? orange : red);
  drawMetricBox(margin + 2*(boxW+8), y, 'Avg Phoneme Error Rate (PER)', avgPER.toFixed(1) + '%', avgPER <= 15 ? green : avgPER <= 40 ? orange : red);
  y += 36;

  // Formulas reference
  doc.setFontSize(8);
  doc.setFont('helvetica','italic');
  doc.setTextColor(...gray);
  doc.text('WER = (Sw + Dw + Iw) / Nw × 100%     |     PER = (Sp + Dp + Ip) / Np × 100%     |     Sacc = max(0, (Np - (Sp+Dp+Ip)) / Np) × 100%', margin, y);
  y += 6;
  doc.text(`Total Phoneme Errors — Substitutions: ${totalSubs}   Deletions: ${totalDels}   Insertions: ${totalIns}   |   Unique Words Tested: ${uniqueWords.size}`, margin, y);
  y += 6;
  // Transcription provenance: a report that mixes simulated and measured
  // attempts must say so, otherwise the metrics read as validated data.
  const engineCounts = new Map();
  sessionHistory.forEach(e => {
    const k = e.asrEngine || ASR_ENGINE.SIMULATED;
    engineCounts.set(k, (engineCounts.get(k) || 0) + 1);
  });
  const engineSummary = Array.from(engineCounts.entries())
    .map(([k, n]) => `${k} (${n})`).join(', ');
  const simulatedCount = engineCounts.get(ASR_ENGINE.SIMULATED) || 0;
  doc.setFont('helvetica', simulatedCount ? 'bold' : 'normal');
  doc.text(`Transcription engine(s): ${engineSummary}`, margin, y);
  if (simulatedCount) {
    y += 5;
    doc.text(`WARNING: ${simulatedCount} attempt(s) were simulated, not transcribed. Those scores are not measurements.`, margin, y);
  }
  y += 10;

  // Divider
  doc.setDrawColor(220,220,230);
  doc.line(margin, y, pageW - margin, y);
  y += 6;

  // Per-word summary
  doc.setFontSize(11);
  doc.setFont('helvetica','bold');
  doc.setTextColor(...dark);
  doc.text('Per-Word Performance Summary', margin, y);
  y += 6;

  // Build per-word data
  const wordData = {};
  h.forEach(e => {
    if (!wordData[e.targetWord]) wordData[e.targetWord] = { ipa: e.targetIpa, attempts: [] };
    wordData[e.targetWord].attempts.push(e);
  });

  const tableBody = Object.entries(wordData).map(([word, data]) => {
    const att = data.attempts;
    const avgA = att.reduce((s,e)=>s+e.accuracy,0)/att.length;
    const avgW = att.reduce((s,e)=>s+e.wer,0)/att.length;
    const avgP = att.reduce((s,e)=>s+e.per,0)/att.length;
    const tS = att.reduce((s,e)=>s+e.subs,0);
    const tD = att.reduce((s,e)=>s+e.dels,0);
    const tI = att.reduce((s,e)=>s+e.ins,0);
    return [word, data.ipa, att.length.toString(), avgA.toFixed(1)+'%', avgW.toFixed(1)+'%', avgP.toFixed(1)+'%', `${tS}/${tD}/${tI}`];
  });

  doc.autoTable({
    startY: y,
    head: [['Word', 'IPA', 'Attempts', 'Avg Acc', 'Avg WER', 'Avg PER', 'S/D/I']],
    body: tableBody,
    margin: { left: margin, right: margin },
    styles: { fontSize: 8, cellPadding: 3 },
    headStyles: { fillColor: purple, textColor: [255,255,255], fontStyle: 'bold', fontSize: 7.5 },
    alternateRowStyles: { fillColor: [248,249,255] },
    didParseCell: function(data) {
      if (data.section === 'body' && data.column.index === 3) {
        const val = parseFloat(data.cell.raw);
        if (val >= 85) data.cell.styles.textColor = green;
        else if (val >= 60) data.cell.styles.textColor = orange;
        else data.cell.styles.textColor = red;
        data.cell.styles.fontStyle = 'bold';
      }
    }
  });
  y = doc.lastAutoTable.finalY + 8;

  // ---- Phoneme Error Matrix + Error-Pattern Trends ----
  // Rows = target ARPAbet phone, cols = phones actually produced.
  // Built from the stored per-attempt alignments, so it reflects every session.
  const matrix = {};        // ref -> { hyp -> count }
  const phonemeTotals = {}; // ref -> { correct, sub, del, ins }
  h.forEach(e => {
    (e.alignment || []).forEach(a => {
      if (a.type === 'insertion') {
        // Extra phones have no reference; track them separately.
        matrix.__ins = matrix.__ins || {};
        matrix.__ins[a.hyp] = (matrix.__ins[a.hyp] || 0) + 1;
        return;
      }
      const ref = a.ref;
      matrix[ref] = matrix[ref] || {};
      matrix[ref][a.hyp || 'X'] = (matrix[ref][a.hyp || 'X'] || 0) + 1;
      phonemeTotals[ref] = phonemeTotals[ref] || { correct: 0, sub: 0, del: 0, ins: 0 };
      if (a.type === 'correct') phonemeTotals[ref].correct++;
      else if (a.type === 'substitution') phonemeTotals[ref].sub++;
      else if (a.type === 'deletion') phonemeTotals[ref].del++;
    });
  });

  const refPhones = Object.keys(matrix).filter(k => k !== '__ins').sort();
  const hypPhones = Array.from(new Set(
    refPhones.flatMap(r => Object.keys(matrix[r]))
  )).sort();

  if (y > 190) { doc.addPage(); y = 20; }

  doc.setFontSize(11);
  doc.setFont('helvetica','bold');
  doc.setTextColor(...dark);
  doc.text('Phoneme Error Matrix', margin, y);
  y += 5;
  doc.setFontSize(7.5);
  doc.setFont('helvetica','italic');
  doc.setTextColor(...gray);
  doc.text('Rows are the target phone, columns are the phone actually produced. Counts pooled across all attempts.', margin, y);
  y += 4;

  if (refPhones.length === 0) {
    doc.setFontSize(8);
    doc.setFont('helvetica','normal');
    doc.setTextColor(...gray);
    doc.text('No phoneme alignments available for this session.', margin, y);
    y += 8;
  } else {
    const matrixHead = [['Target \\ Prod'].concat(hypPhones.map(p => p === 'X' ? '(del)' : p))];
    const matrixBody = refPhones.map(r => [r].concat(
      hypPhones.map(p => String(matrix[r][p] || 0))
    ));
    doc.autoTable({
      startY: y,
      head: matrixHead,
      body: matrixBody,
      margin: { left: margin, right: margin },
      styles: { fontSize: 7, cellPadding: 2, halign: 'center' },
      headStyles: { fillColor: purple, textColor: [255,255,255], fontStyle: 'bold', fontSize: 6.5 },
      alternateRowStyles: { fillColor: [248,249,255] },
      didParseCell: function(data) {
        if (data.section === 'body') {
          const n = parseInt(data.cell.raw, 10);
          // Off-diagonal counts are confusions; diagonal counts are correct hits.
          const diag = data.row.index >= 0 && hypPhones[data.column.index - 1] === refPhones[data.row.index];
          data.cell.styles.textColor = n === 0 ? [190,190,200]
            : diag ? green : orange;
          if (n > 0) data.cell.styles.fontStyle = 'bold';
        }
      }
    });
    y = doc.lastAutoTable.finalY + 8;
  }

  // Error-pattern trends
  if (y > 200) { doc.addPage(); y = 20; }
  doc.setFontSize(11);
  doc.setFont('helvetica','bold');
  doc.setTextColor(...dark);
  doc.text('Error-Pattern Trends', margin, y);
  y += 7;

  const trendRows = [];
  // Most frequent confusions (substitutions).
  refPhones.forEach(r => {
    Object.keys(matrix[r]).forEach(p => {
      if (p !== r && p !== 'X') trendRows.push({ kind: 'Substitution', pattern: `${r} \u2192 ${p}`, n: matrix[r][p] });
    });
  });
  // Most frequent omissions (deletions).
  refPhones.forEach(r => {
    const n = matrix[r].X || 0;
    if (n > 0) trendRows.push({ kind: 'Deletion', pattern: `${r} \u2192 (omitted)`, n });
  });
  // Most frequent additions (insertions).
  if (matrix.__ins) {
    Object.keys(matrix.__ins).forEach(p => {
      trendRows.push({ kind: 'Insertion', pattern: `(added) \u2192 ${p}`, n: matrix.__ins[p] });
    });
  }
  trendRows.sort((a, b) => b.n - a.n);
  const topTrends = trendRows.slice(0, 10);

  if (topTrends.length === 0) {
    doc.setFontSize(8);
    doc.setFont('helvetica','normal');
    doc.setTextColor(...green);
    doc.text('No phoneme-level errors recorded \u2014 all target phones were produced correctly.', margin, y);
    y += 8;
  } else {
    doc.autoTable({
      startY: y,
      head: [['Error Type', 'Pattern', 'Count', 'Share']],
      body: topTrends.map(t => [
        t.kind, t.pattern, String(t.n),
        ((t.n / Math.max(1, totalSubs + totalDels + totalIns)) * 100).toFixed(1) + '%',
      ]),
      margin: { left: margin, right: margin },
      styles: { fontSize: 8, cellPadding: 2.5 },
      headStyles: { fillColor: orange, textColor: [255,255,255], fontStyle: 'bold', fontSize: 7.5 },
      alternateRowStyles: { fillColor: [255,250,247] },
    });
    y = doc.lastAutoTable.finalY + 8;
  }

  // Per-phoneme difficulty ranking
  if (y > 200) { doc.addPage(); y = 20; }
  const difficulty = Object.keys(phonemeTotals).map(r => {
    const t = phonemeTotals[r];
    const total = t.correct + t.sub + t.del;
    return { phone: r, total, errRate: total ? ((t.sub + t.del) / total) * 100 : 0 };
  }).filter(d => d.total > 0).sort((a, b) => b.errRate - a.errRate).slice(0, 10);

  if (difficulty.length > 0) {
    doc.setFontSize(11);
    doc.setFont('helvetica','bold');
    doc.setTextColor(...dark);
    doc.text('Most Difficult Phonemes', margin, y);
    y += 6;
    doc.autoTable({
      startY: y,
      head: [['Target Phone', 'Occurrences', 'Error Rate', 'Primary Error']],
      body: difficulty.map(d => {
        const t = phonemeTotals[d.phone];
        const primary = t.sub >= t.del ? 'Substitution' : 'Deletion';
        return [d.phone, String(d.total), d.errRate.toFixed(1) + '%', primary];
      }),
      margin: { left: margin, right: margin },
      styles: { fontSize: 8, cellPadding: 2.5, halign: 'center' },
      headStyles: { fillColor: dark, textColor: [255,255,255], fontStyle: 'bold', fontSize: 7.5 },
      alternateRowStyles: { fillColor: [248,249,255] },
      didParseCell: function(data) {
        if (data.section === 'body' && data.column.index === 2) {
          const val = parseFloat(data.cell.raw);
          data.cell.styles.textColor = val >= 40 ? red : val >= 20 ? orange : green;
          data.cell.styles.fontStyle = 'bold';
        }
      }
    });
    y = doc.lastAutoTable.finalY + 8;
  }

  // CSV pointer
  doc.setFontSize(7.5);
  doc.setFont('helvetica','italic');
  doc.setTextColor(...gray);
  doc.text('A full per-attempt CSV dump (including raw phoneme strings and alignments) is available from the Report tab.', margin, y);

  // Check for page overflow
  if (y > 250) { doc.addPage(); y = 20; }

  // Detailed attempt log
  doc.setFontSize(11);
  doc.setFont('helvetica','bold');
  doc.setTextColor(...dark);
  doc.text('Detailed Attempt Log', margin, y);
  y += 6;

  const detailBody = h.map(e => {
    const time = new Date(e.timestamp).toLocaleTimeString();
    return [e.targetWord, e.spokenText, e.accuracy.toFixed(1)+'%', e.wer.toFixed(1)+'%', e.per.toFixed(1)+'%', `${e.subs}/${e.dels}/${e.ins}`, time];
  });

  doc.autoTable({
    startY: y,
    head: [['Target', 'Spoken', 'Accuracy', 'WER', 'PER', 'S/D/I', 'Time']],
    body: detailBody,
    margin: { left: margin, right: margin },
    styles: { fontSize: 7.5, cellPadding: 2.5 },
    headStyles: { fillColor: purple, textColor: [255,255,255], fontStyle: 'bold', fontSize: 7 },
    alternateRowStyles: { fillColor: [248,249,255] },
    didParseCell: function(data) {
      if (data.section === 'body' && data.column.index === 2) {
        const val = parseFloat(data.cell.raw);
        if (val >= 85) data.cell.styles.textColor = green;
        else if (val >= 60) data.cell.styles.textColor = orange;
        else data.cell.styles.textColor = red;
        data.cell.styles.fontStyle = 'bold';
      }
    }
  });
  y = doc.lastAutoTable.finalY + 10;

  // Check for page overflow for interpretation
  if (y > 230) { doc.addPage(); y = 20; }

  // Interpretation / Clinical Notes
  doc.setFontSize(11);
  doc.setFont('helvetica','bold');
  doc.setTextColor(...dark);
  doc.text('Clinical Interpretation Notes', margin, y);
  y += 7;

  doc.setFontSize(8);
  doc.setFont('helvetica','normal');
  doc.setTextColor(...gray);

  const notes = [];
  if (avgPER <= 15) notes.push('• Average PER is within the target threshold of <15%, indicating strong phoneme-level accuracy.');
  else if (avgPER <= 30) notes.push('• Average PER is moderate (15–30%). Targeted phoneme practice is recommended.');
  else notes.push('• Average PER exceeds 30%, suggesting significant phoneme-level difficulties. Clinical consultation advised.');

  if (avgWER <= 20) notes.push('• Average WER is within the acceptable target of <20%, indicating good word-level recognition.');
  else notes.push('• Average WER exceeds 20%. Further evaluation of articulatory patterns is recommended.');

  if (totalSubs > totalDels + totalIns) notes.push('• Substitutions are the predominant error type, suggesting articulatory placement difficulties.');
  if (totalDels > totalSubs) notes.push('• Deletions are elevated, indicating possible phoneme omission patterns.');
  if (totalIns > 0) notes.push(`• ${totalIns} insertion(s) detected, which may indicate extraneous vocalizations.`);

  notes.push('');
  notes.push('Note: Metrics computed using Levenshtein Dynamic Programming Alignment per the EchoVoice methodology.');
  notes.push('Phoneme Error Rate formula: PER = (Sp + Dp + Ip) / Np × 100%');
  notes.push('Word Error Rate formula: WER = (Sw + Dw + Iw) / Nw × 100%');
  notes.push('Pronunciation Accuracy: Sacc = max(0, (Np - (Sp + Dp + Ip)) / Np) × 100%');

  notes.forEach(n => {
    doc.text(n, margin, y);
    y += 4.5;
  });

  y += 4;
  // ICC reference
  doc.setFontSize(8);
  doc.setFont('helvetica','italic');
  doc.text('ICC Agreement Scale Reference — Below 0.50: Poor | 0.50–0.75: Moderate | 0.75–0.90: Good | Above 0.90: Excellent', margin, y);
  y += 8;

  // Footer
  doc.setDrawColor(...purple);
  doc.setLineWidth(0.3);
  doc.line(margin, y, pageW - margin, y);
  y += 5;
  doc.setFontSize(7);
  doc.setTextColor(...gray);
  doc.text('EchoVoice — DMMMSU South La Union Campus, College of Computer Science', margin, y);
  doc.text(`Generated: ${new Date().toLocaleString()}`, pageW - margin, y, { align: 'right' });

  // Save
  const fileName = `EchoVoice_Clinician_Report_${childName.replace(/\s+/g,'_')}_${sessDate}.pdf`;
  doc.save(fileName);
  showToast('📥 Clinician Report downloaded!');
}

// ===== Manuscript Content =====
function renderManuscript() {
  const content = $('manuscriptContent');
  content.innerHTML = `
    <h2>ECHOVOICE: A Web-Based Pronunciation Assessment for Speech Therapy</h2>
    <p style="font-size:.82rem; color:var(--text-light);">
      <strong>Authors:</strong> Kurt Daryl M. Nievera, Kate Ann H. Cerezo, Maica Jenish M. Doctolero,
      Rolando Jr. T. Gonzales, Jefferson S. Paglingayen<br>
      <strong>Institution:</strong> Don Mariano Marcos Memorial State University, South La Union Campus,
      College of Computer Science, Agoo, La Union<br>
      <strong>Degree:</strong> Bachelor of Science in Computer Science &bull; October 2026<br>
      <strong>Adviser:</strong> Dr. Clarisa V. Albarillo
    </p>

    <h2>Abstract</h2>
    <p>Children with speech sound disorders need frequent, focused pronunciation practice, yet access to Speech-Language Pathologists (SLPs) is limited by geography, cost, and clinic capacity. This study presents EchoVoice, a web-based application for isolated-word pronunciation practice that supports — but does not replace — the clinical judgment of a licensed SLP.</p>
    <p>EchoVoice fine-tunes a self-supervised HuBERT-Large acoustic model on pediatric speech, applying acoustic data augmentation and phoneme-level alignment to compute Phoneme Error Rate (PER) and Word Error Rate (WER) for known target words. The system generates dual exportable progress reports: a clinician-facing report for the SLP and a child-facing summary for home practice.</p>
    <p>The system was developed using the Scrum framework within a Machine Learning Development Life Cycle (MLDLC), using the PERCEPT-GFTA corpus as the primary dataset and five child participants for local validation. Technical accuracy is measured through PER and WER, clinical agreement through the Intraclass Correlation Coefficient (ICC(2,1)), and usability through the System Usability Scale (SUS).</p>
    <p><strong>Keywords:</strong> pronunciation assessment, pediatric speech, self-supervised learning, HuBERT, phoneme error rate, speech therapy</p>

    <h2>Chapter 1: Introduction</h2>
    <h3>Situation Analysis</h3>
    <p>Automatic Speech Recognition (ASR) technology has experienced rapid architectural advancement over the past decade, shifting from traditional Gaussian Mixture Models and Hidden Markov Models (GMM-HMMs) to end-to-end deep neural networks and self-supervised transformer representations. While modern foundation models achieve near-human transcription fidelity when evaluated on adult speech, adapting these systems to children's speech remains one of the most persistent and structural challenges in speech-processing machine learning.</p>
    <p>Standard ASR models trained predominantly on adult acoustic data exhibit catastrophic performance degradation when deployed on pediatric speech inputs. This failure is fundamentally rooted in severe acoustic, anatomical, and behavioral domain mismatches. Pediatric speech features higher fundamental frequencies (F0), shorter vocal tract lengths leading to significantly shifted formant profiles (F1, F2, F3), undeveloped articulatory motor control, and extreme intra- and inter-speaker acoustic variability.</p>
    <p>In the Philippines, access to speech-language pathology services is constrained by a documented shortage of licensed practitioners — a need underscored by the fact that the country has roughly 672 licensed SLPs for a population exceeding 115 million. Compounding this gap, available pediatric corpora remain sparse, and isolated-word tasks expose acoustic models to precisely the noisier, shorter utterances where they degrade most.</p>
    <p>Furthermore, off-the-shelf commercial ASR models often "autocorrect" atypical speech into standard orthography, masking articulatory errors rather than surfacing them. HuBERT shows promise for phoneme-level recognition in children's speech, but its performance degrades in noisier, single-word conditions — motivating EchoVoice's domain-specific fine-tuning, data augmentation, and known-target scoring.</p>
    <p>Despite growing Philippine ASR work on Filipino speech, and recent systems such as SamurAI and YugTalk, no prior work synthesizes self-supervised representation learning, augmentation, and phoneme-level alignment into a single acoustic evaluation engine evaluated for clinical agreement with a licensed SLP and packaged as a deployable web application with clinician-facing reporting.</p>
    <p>To bridge these gaps, EchoVoice presents a web-based application for isolated-word pronunciation practice powered by a fine-tuned HuBERT-Large model. The system applies acoustic data augmentation and phoneme-level alignment to compute PER and WER, and produces dual exportable progress reports for the clinician and the child. It targets WER &lt; 20%, PER &lt; 15%, ICC(2,1) &gt; 0.75, and a SUS score of at least 70, supporting SDG 3, 4, and 10.</p>
    <p>This study also aligns with three United Nations Sustainable Development Goals. It supports SDG 3 (Good Health and Well-Being), SDG 4 (Quality Education), and SDG 10 (Reduced Inequalities) by delivering a browser-based pronunciation assessment tool that can extend clinical support to resource-constrained settings.</p>

    <h3>Statement of the Objectives</h3>
    <p>The primary objective of this study is to design, develop, and evaluate EchoVoice, a web-based application for automated, phoneme-level pronunciation assessment of children's speech using a fine-tuned HuBERT-Large model.</p>
    <p>Specifically, the study aims to:</p>
    <ul style="padding-left:20px; margin-bottom:12px;">
      <li>Fine-tune a pre-trained HuBERT-Large self-supervised acoustic model on pediatric speech corpora</li>
      <li>Develop an automated phoneme alignment and scoring engine utilizing frame-level probability projections and Levenshtein dynamic programming alignment</li>
      <li>Produce dual exportable progress reports — a clinician-facing report and a child-facing practice summary</li>
      <li>Validate the model's automated scoring accuracy against the perceptual ratings of a licensed Speech-Language Pathologist using the Intraclass Correlation Coefficient (ICC)</li>
      <li>Assess system usability through the System Usability Scale (SUS), targeting a score of at least 70</li>
    </ul>

    <h2>Chapter 2: Methodology</h2>
    <h3>Research Design</h3>
    <p>This study adopts a quantitative-experimental and descriptive research design, structured within a Machine Learning Development Life Cycle (MLDLC) and organized using the Scrum framework. Development proceeds in short, iterative sprints covering data preparation, model fine-tuning, evaluation, web application integration, and reporting, with the acoustic pipeline operationalized via transfer learning using the HuBERT-Large architecture.</p>

    <h3>Key Formulas</h3>
    <p><strong>CTC Loss:</strong> ℒ<sub>CTC</sub> = -ln P(Y|X), where X represents the input sequence of acoustic frames and Y represents the ground-truth sequence of canonical target phonemes.</p>
    <p><strong>Pronunciation Accuracy:</strong> S<sub>acc</sub> = max(0, (N<sub>p</sub> - (S<sub>p</sub> + D<sub>p</sub> + I<sub>p</sub>)) / N<sub>p</sub>) × 100%</p>
    <p><strong>PER:</strong> PER = (S<sub>p</sub> + D<sub>p</sub> + I<sub>p</sub>) / N<sub>p</sub> × 100%</p>
    <p><strong>WER:</strong> WER = (S<sub>w</sub> + D<sub>w</sub> + I<sub>w</sub>) / N<sub>w</sub> × 100%</p>

    <h3>Data Augmentation</h3>
    <p>Three data augmentation techniques are applied: (1) Time and frequency masking via SpecAugment, (2) Stochastic pitch-shifting between -3.0 and +4.0 semitones, and (3) Ambient background noise mixing at SNR ranging from 0–15 dB.</p>

    <h3>Model Architecture</h3>
    <p>The primary acoustic engine is built upon the HuBERT-Large architecture. The base HuBERT encoder processes raw audio waveforms into 20 ms acoustic frames using a CNN temporal encoder followed by a 24-layer transformer stack. Frame representations are projected onto a linear classification layer mapping to an IPA phoneme vocabulary subset, optimized using CTC Loss.</p>

    <h3>Clinical Validation and Usability</h3>
    <p>Inter-rater reliability and clinical agreement are measured using the Intraclass Correlation Coefficient ICC(2,1). Target: ICC &gt; 0.75. Ratings below 0.50 indicate poor agreement, 0.50–0.75 moderate, 0.75–0.90 good, and above 0.90 excellent. System usability is measured through the System Usability Scale (SUS), with an acceptance target of at least 70. Automated scores are presented as practice feedback and never as a clinical diagnosis, preserving the SLP's role in interpretation.</p>

    <h3>Dataset</h3>
    <p>Primary dataset: PERCEPT-GFTA corpus (Benway et al., 2022) from TalkBank — 350 talkers aged 6–17. Local validation: Growth Journey Learning Center Inc., Agoo, La Union — 5 pediatric participants with ASD-related speech sound difficulties, each performing 30 target words from GFTA (150 audio samples total).</p>

    <h3>Ethical Considerations</h3>
    <p>All data handling adheres strictly to the Philippine Data Privacy Act of 2012 (R.A. 10173) and the 2022 National Ethical Guidelines for Research Involving Human Participants (NEGRIHP). Audio waveforms are stripped of metadata and tagged with pseudonymized identifiers. All samples stored on AES-256 encrypted volumes with TLS/SSL transfer protocols.</p>
  `;
}

// ===== Toast =====
function showToast(msg) {
  toastEl.textContent = msg;
  toastEl.classList.add('show');
  setTimeout(() => toastEl.classList.remove('show'), 2800);
}

// ===== Background shapes =====
(function() {
  const c = $('bgShapes');
  const colors = ['#6c5ce7','#fd79a8','#00b894','#74b9ff','#a29bfe'];
  for (let i = 0; i < 8; i++) {
    const s = document.createElement('div');
    s.className = 'bg-shape';
    const size = 100 + Math.random() * 250;
    s.style.width = size + 'px';
    s.style.height = size + 'px';
    s.style.left = Math.random() * 100 + '%';
    s.style.top = Math.random() * 100 + '%';
    s.style.background = colors[i % colors.length];
    s.style.animationDuration = (15 + Math.random() * 20) + 's';
    s.style.animationDelay = (Math.random() * 10) + 's';
    c.appendChild(s);
  }
})();

// ===== Init =====
$('sessionDate').valueAsDate = new Date();
renderCategories();
renderWordGrid();
renderManuscript();


// ===== Splash Screen & Authentication =====
const AUTH_ACCOUNTS_KEY = 'echovoice_accounts';
const AUTH_SESSION_KEY = 'echovoice_session';
const appWrapper = $('appWrapper');
const splashEl = $('splash');
const authScreenEl = $('authScreen');
const authTabLogin = $('authTabLogin');
const authTabSignup = $('authTabSignup');
const loginForm = $('loginForm');
const signupForm = $('signupForm');
const loginUsername = $('loginUsername');
const loginPassword = $('loginPassword');
const signupUsername = $('signupUsername');
const signupPassword = $('signupPassword');
const signupConfirm = $('signupConfirm');
const authMsg = $('authMsg');
const logoutBtn = $('logoutBtn');

function getAccounts() {
  try { return JSON.parse(localStorage.getItem(AUTH_ACCOUNTS_KEY) || '[]'); }
  catch (e) { return []; }
}
function saveAccounts(accounts) { localStorage.setItem(AUTH_ACCOUNTS_KEY, JSON.stringify(accounts)); }

function fallbackHash(str) {
  let h = 5381;
  for (let i = 0; i < str.length; i++) { h = ((h << 5) + h + str.charCodeAt(i)) >>> 0; }
  return 'fnv_' + h.toString(16);
}
async function hashPassword(pw, salt) {
  const input = salt + '::' + pw;
  if (window.crypto && crypto.subtle) {
    const data = new TextEncoder().encode(input);
    const buf = await crypto.subtle.digest('SHA-256', data);
    return 'sha256_' + Array.from(new Uint8Array(buf)).map(b => b.toString(16).padStart(2, '0')).join('');
  }
  return fallbackHash(input);
}

function currentUser() { return localStorage.getItem(AUTH_SESSION_KEY) || null; }

function clearChildProfile() {
  currentChildId = null;
  localStorage.removeItem('echovoice_child_id');
  const nameEl = $('childName'), ageEl = $('childAge'), dateEl = $('sessionDate'), msgEl = $('profileSaveMsg');
  if (nameEl) nameEl.value = '';
  if (ageEl) ageEl.value = '';
  if (dateEl) dateEl.valueAsDate = new Date();
  if (msgEl) msgEl.textContent = '';
}

function showApp() {
  clearChildProfile();
  authScreenEl.style.display = 'none';
  appWrapper.style.display = 'block';
  renderProfileIdentity();
  loadHistoryForUser(currentUser());
}

function showAuth() {
  clearChildProfile();
  sessionHistory = [];
  appWrapper.style.display = 'none';
  authScreenEl.style.display = 'flex';
  renderProfileIdentity();
  if (appDrawer.classList.contains('open')) setDrawer(false);
}

function setAuthMsg(text, ok) {
  const el = authMsg;
  el.textContent = text || '';
  el.className = 'auth-msg' + (ok ? ' ok' : '');
}

function switchAuthTab(tab) {
  const isLogin = tab === 'login';
  authTabLogin.classList.toggle('active', isLogin);
  authTabSignup.classList.toggle('active', !isLogin);
  loginForm.style.display = isLogin ? 'block' : 'none';
  signupForm.style.display = isLogin ? 'none' : 'block';
  setAuthMsg('');
}

authTabLogin.addEventListener('click', () => switchAuthTab('login'));
authTabSignup.addEventListener('click', () => switchAuthTab('signup'));

loginForm.addEventListener('submit', async (e) => {
  e.preventDefault();
  const username = loginUsername.value.trim().toLowerCase();
  const password = loginPassword.value;
  if (!username || !password) { setAuthMsg('Enter your username and password.'); return; }
  const account = getAccounts().find(a => a.u === username);
  if (!account) { setAuthMsg('No account found. Please sign up first.'); return; }
  const hash = await hashPassword(password, account.s);
  if (hash !== account.h) { setAuthMsg('Incorrect password. Try again.'); return; }
  localStorage.setItem(AUTH_SESSION_KEY, account.u);
  showApp();
  setAuthMsg('');
  showToast('👋 Welcome back, ' + account.u + '!');
});

signupForm.addEventListener('submit', async (e) => {
  e.preventDefault();
  const username = signupUsername.value.trim().toLowerCase();
  const password = signupPassword.value;
  const confirm = signupConfirm.value;
  if (!username) { setAuthMsg('Choose a username.'); return; }
  if (!/^[a-z0-9_.]{3,20}$/.test(username)) { setAuthMsg('Username: 3-20 letters, numbers, dots, or underscores.'); return; }
  if (password.length < 6) { setAuthMsg('Password must be at least 6 characters.'); return; }
  if (password !== confirm) { setAuthMsg('Passwords do not match.'); return; }
  const accounts = getAccounts();
  if (accounts.some(a => a.u === username)) { setAuthMsg('That username is already taken.'); return; }
  const salt = Math.random().toString(36).slice(2) + Date.now().toString(36);
  const hash = await hashPassword(password, salt);
  accounts.push({ u: username, s: salt, h: hash, created: new Date().toISOString() });
  saveAccounts(accounts);
  localStorage.setItem(AUTH_SESSION_KEY, username);
  showApp();
  setAuthMsg('');
  showToast('🎉 Account created. Welcome to EchoVoice!');
});

logoutBtn.addEventListener('click', () => {
  localStorage.removeItem(AUTH_SESSION_KEY);
  showAuth();
  switchAuthTab('login');
  showToast('👋 You have been logged out.');
});

// Boot: splash -> (app | auth)
(function boot() {
  setTimeout(() => {
    splashEl.classList.add('hidden');
    setTimeout(() => {
      splashEl.style.display = 'none';
      if (currentUser()) showApp(); else showAuth();
    }, 150);
  }, 250);
})();
