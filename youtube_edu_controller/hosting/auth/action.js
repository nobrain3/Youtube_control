// 큐비엔 Firebase 이메일 작업 처리 페이지 (#99).
//
// Firebase 기본 처리 페이지는 링크의 apiKey 파라미터가 필요한데, 이 프로젝트는
// 인증 백엔드의 API 키 매핑이 비어 있어 링크에 apiKey가 빈 값으로 들어간다.
// 이 페이지는 apiKey를 링크에서 읽지 않고 Hosting 예약 URL(/__/firebase/init.json)에서
// 가져오므로 그 문제와 무관하게 동작한다.
//
// 참고: https://firebase.google.com/docs/auth/custom-email-handler
import { initializeApp } from 'https://www.gstatic.com/firebasejs/13.0.0/firebase-app.js';
import {
  getAuth,
  verifyPasswordResetCode,
  confirmPasswordReset,
  applyActionCode,
  checkActionCode,
} from 'https://www.gstatic.com/firebasejs/13.0.0/firebase-auth.js';

const app = document.getElementById('app');

/**
 * 쿼리 파라미터를 읽는다. 일부 메일 서비스가 `&`를 `&amp;`로 바꿔
 * `amp;oobCode` 같은 키가 생기는 경우도 처리한다.
 */
function readParams() {
  const params = {};
  for (const [rawKey, value] of new URLSearchParams(window.location.search)) {
    const key = rawKey.replace(/^(amp;)+/, '');
    if (!(key in params)) params[key] = value;
  }
  return params;
}

/** 화면 내용을 바꾼다. 텍스트는 모두 textContent로 넣어 HTML로 해석되지 않게 한다. */
function render({ title, body = '', status = '', children = [] }) {
  app.className = `card ${status ? `status-${status}` : ''}`;
  app.replaceChildren();
  const brand = document.createElement('div');
  brand.className = 'brand';
  brand.textContent = '큐비엔';
  const h1 = document.createElement('h1');
  h1.textContent = title;
  app.append(brand, h1);
  if (body) {
    const p = document.createElement('p');
    p.textContent = body;
    app.append(p);
  }
  app.append(...children);
}

function renderError(message) {
  render({ title: '처리할 수 없는 링크입니다', body: message, status: 'error' });
}

function messageFor(error) {
  switch (error?.code) {
    case 'auth/expired-action-code':
      return '링크가 만료되었습니다. 큐비엔 앱에서 다시 요청해주세요.';
    case 'auth/invalid-action-code':
      return '링크가 올바르지 않거나 이미 사용되었습니다. 큐비엔 앱에서 다시 요청해주세요.';
    case 'auth/user-disabled':
      return '사용이 중지된 계정입니다.';
    case 'auth/user-not-found':
      return '계정을 찾을 수 없습니다.';
    case 'auth/weak-password':
      return '비밀번호가 너무 약합니다. 6자 이상 입력해주세요.';
    case 'auth/network-request-failed':
      return '네트워크 연결을 확인한 뒤 다시 시도해주세요.';
    default:
      return `처리 중 오류가 발생했습니다. (${error?.code ?? '알 수 없음'})`;
  }
}

function field(labelText, id) {
  const label = document.createElement('label');
  label.htmlFor = id;
  label.textContent = labelText;
  const input = document.createElement('input');
  input.type = 'password';
  input.id = id;
  input.autocomplete = 'new-password';
  input.minLength = 6;
  input.required = true;
  return [label, input];
}

async function handleResetPassword(auth, oobCode) {
  let email;
  try {
    email = await verifyPasswordResetCode(auth, oobCode);
  } catch (error) {
    renderError(messageFor(error));
    return;
  }

  const form = document.createElement('form');
  const [pwLabel, pwInput] = field('새 비밀번호 (6자 이상)', 'password');
  const [cfLabel, cfInput] = field('새 비밀번호 확인', 'confirm');
  const msg = document.createElement('div');
  msg.className = 'msg error';
  const submit = document.createElement('button');
  submit.type = 'submit';
  submit.textContent = '비밀번호 변경';
  form.append(pwLabel, pwInput, cfLabel, cfInput, msg, submit);

  form.addEventListener('submit', async (event) => {
    event.preventDefault();
    msg.textContent = '';
    if (pwInput.value.length < 6) {
      msg.textContent = '비밀번호는 6자 이상이어야 합니다.';
      return;
    }
    if (pwInput.value !== cfInput.value) {
      msg.textContent = '비밀번호가 일치하지 않습니다.';
      return;
    }
    submit.disabled = true;
    submit.textContent = '변경하는 중…';
    try {
      await confirmPasswordReset(auth, oobCode, pwInput.value);
      render({
        title: '비밀번호가 변경되었습니다',
        body: '큐비엔 앱으로 돌아가 새 비밀번호로 로그인해주세요.',
        status: 'ok',
      });
    } catch (error) {
      msg.textContent = messageFor(error);
      submit.disabled = false;
      submit.textContent = '비밀번호 변경';
    }
  });

  render({
    title: '비밀번호 재설정',
    body: `${email} 계정의 새 비밀번호를 입력해주세요.`,
    children: [form],
  });
  pwInput.focus();
}

async function handleVerifyEmail(auth, oobCode) {
  try {
    await applyActionCode(auth, oobCode);
    render({
      title: '이메일 인증이 완료되었습니다',
      body: '큐비엔 앱으로 돌아가 계속 이용해주세요.',
      status: 'ok',
    });
  } catch (error) {
    renderError(messageFor(error));
  }
}

async function handleRecoverEmail(auth, oobCode) {
  try {
    const info = await checkActionCode(auth, oobCode);
    await applyActionCode(auth, oobCode);
    render({
      title: '이메일이 복구되었습니다',
      body: `로그인 이메일이 ${info.data.email ?? '이전 이메일'}(으)로 되돌려졌습니다. ` +
        '본인이 변경하지 않았다면 큐비엔 앱에서 비밀번호도 재설정해주세요.',
      status: 'ok',
    });
  } catch (error) {
    renderError(messageFor(error));
  }
}

async function main() {
  const { mode, oobCode } = readParams();
  if (!mode || !oobCode) {
    renderError('링크에 필요한 정보가 없습니다. 메일의 링크를 다시 눌러주세요.');
    return;
  }

  let config;
  try {
    const response = await fetch('/__/firebase/init.json');
    if (!response.ok) throw new Error(`init.json ${response.status}`);
    config = await response.json();
  } catch (error) {
    renderError('서비스 설정을 불러오지 못했습니다. 잠시 후 다시 시도해주세요.');
    return;
  }

  const auth = getAuth(initializeApp(config));
  auth.languageCode = 'ko';

  switch (mode) {
    case 'resetPassword':
      await handleResetPassword(auth, oobCode);
      break;
    case 'verifyEmail':
      await handleVerifyEmail(auth, oobCode);
      break;
    case 'recoverEmail':
      await handleRecoverEmail(auth, oobCode);
      break;
    default:
      renderError('지원하지 않는 요청입니다.');
  }
}

main();
