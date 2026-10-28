const jsonRequest = async (url, body) => {
  const headers={'Content-Type': 'application/json'};
  const token=sessionStorage.getItem('auth_token');
  if(token) headers.Authorization=`Bearer ${token}`;
  const response = await fetch(url, {method: 'POST', headers, body: JSON.stringify(body)});
  const data = await response.json();
  if (!response.ok) {const error=new Error(data.error?.message || 'The request could not be completed.');error.status=response.status;error.code=data.error?.code;throw error;}
  return data;
};
const showMessage = (node, text, isError=false) => { node.textContent=text; node.classList.toggle('error', isError); };
const showDialog = (id) => { const dialog=document.getElementById(id); if(dialog && !dialog.open) dialog.showModal(); };
document.querySelector('#feedback-form')?.addEventListener('submit', async (event) => {
  event.preventDefault(); const form=event.currentTarget; const message=form.querySelector('.form-message');
  const body=Object.fromEntries(new FormData(form).entries());
  try { await jsonRequest('/api/feedback', body); form.reset(); showMessage(message, 'Thanks. Your message was received.'); }
  catch (error) { showMessage(message, error.message, true); }
});

const registerForm=document.querySelector('#register-form');
registerForm?.addEventListener('submit', async (event) => {
  event.preventDefault(); const form=event.currentTarget; const message=form.querySelector('.form-message');
  const body=Object.fromEntries(new FormData(form).entries());
  try {
    await jsonRequest('/api/auth/register', body);
    showMessage(message, 'Registration complete. Taking you to login…'); form.reset();
    window.setTimeout(()=>window.location.assign('/login?registered=1'),650);
  } catch (error) {
    if(error.message.includes('already exists')){
      showMessage(message, 'An account already exists with these details. You can log in with its contact number.');
    } else showMessage(message, error.message, true);
  }
});

const loginForm=document.querySelector('#login-form');
if(loginForm){
  const gateMessage=document.querySelector('#login-gate-message');
  if(new URLSearchParams(window.location.search).has('registered')) showMessage(gateMessage,'Registration complete. Log in with your contact number and password.');
  loginForm.addEventListener('submit',async(event)=>{
    event.preventDefault();
    const form=event.currentTarget; const message=form.querySelector('.form-message'); const body=Object.fromEntries(new FormData(form).entries());
    try { const result=await jsonRequest('/api/auth/login',body); sessionStorage.setItem('auth_token',result.token); window.location.assign('/'); }
    catch(error){if(error.code==='account_not_registered'){showMessage(message,'No account is registered with this contact number. Please register first.',true);showDialog('register-required-dialog');}else showMessage(message,error.code==='invalid_credentials'?'The password is incorrect for this registered contact number.':error.message,true);}
  });
}
const intakeForm=document.querySelector('#intake-form');
if (intakeForm) {
  const nameInput=document.querySelector('#intake-name'); const options=document.querySelector('#food-options'); let foods=[]; let timer;
  nameInput.addEventListener('input', () => {
    clearTimeout(timer); const query=nameInput.value.trim(); if(query.length<2){options.replaceChildren();return;}
    timer=setTimeout(async()=>{try{const response=await fetch(`/api/foods?q=${encodeURIComponent(query)}&limit=30`);const data=await response.json();foods=data.items||[];options.replaceChildren(...foods.map(food=>{const option=document.createElement('option');option.value=food.name;return option;}));}catch(_){options.replaceChildren();}},180);
  });
  intakeForm.addEventListener('submit', async (event) => {
    event.preventDefault(); const message=document.querySelector('#intake-message');
    if(!sessionStorage.getItem('auth_token')){showDialog('login-required-dialog');return;}
    const formData=new FormData(intakeForm); const body=Object.fromEntries(formData.entries());
    try {
      const result=await jsonRequest('/api/intake/analyze',body);
      document.querySelector('#result-name').textContent=result.intake_name;
      document.querySelector('#result-time').textContent=result.intake_time;
      document.querySelector('#result-portion').textContent=`Portion: ${result.portion_grams} g · Nutrition values are estimates`;
      const rows=document.querySelector('#nutrition-rows'); rows.replaceChildren(...Object.entries(result.nutrition).map(([label,value])=>{const tr=document.createElement('tr');const th=document.createElement('th');th.scope='row';th.textContent=label;const td=document.createElement('td');td.textContent=value==null?'Not available':`${Number(value).toFixed(2)} ${label.match(/\(([^)]+)\)$/)?.[1]||''}`;tr.append(th,td);return tr;}));
      document.querySelector('#nutrition-result').hidden=false; showMessage(message,'');
    } catch(error) {
      document.querySelector('#nutrition-result').hidden=true;
      if(error.status===401){sessionStorage.removeItem('auth_token');showDialog('login-required-dialog');showMessage(message,'Please log in to analyze this intake.',true);}
      else showMessage(message,error.message,true);
    }
  });
}
