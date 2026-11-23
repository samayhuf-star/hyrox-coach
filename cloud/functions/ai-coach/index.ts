import { authenticate, db, identity, rpc, removeAuthUser } from './db.ts';
import { answer } from './provider.ts';
import { purchaseConfig, syncPurchases } from './purchases.ts';
const uuid = (x: unknown): x is string => typeof x === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(x);
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' } });
const messages: Record<string,string> = {
 sign_in_required: 'Please sign in again to use Coach.', verified_email_required: 'Verify your email to use Coach.',
 coach_not_ready: 'Coach is not connected to its AI service yet. Your credits have not been used.',
 consent_required: 'Please review and accept the AI privacy notice first.', already_pending: 'Your previous reply is still being prepared. Refresh in a moment.',
 rate_limit: 'Please take a moment before sending another question.', daily_limit: 'Coach has reached its service limit today. Try again tomorrow. Your credit is safe.',
 no_credits: 'You have no credits left. Your next monthly allowance is shown in your wallet.',
 provider_unavailable: 'Coach could not reply this time. No credit was used. Please try again.',
 purchase_verification_unavailable: 'We could not verify purchased credits. Try refreshing your wallet before sending another question.',
 invalid_request: 'Please use a message of 1–1,600 characters.', request_conflict: 'This request could not be retried. Refresh your conversation.',
 request_deleted: 'This conversation was deleted. Start a new question; no additional credit was used.',
 delete_pending: 'Wait for the current reply to finish before deleting.', delete_unavailable: 'Your account could not be deleted. Please try again.'
};
Deno.serve(async (req: Request) => {
 if (req.method !== 'POST') return json({ error: 'Use POST.' },405);
 if (Number(req.headers.get('Content-Length') ?? 0) > 16000) return json({ error: messages.invalid_request },413);
 let userID: string | undefined;
 let requestID: string | undefined;
 let reserved = false;
 try {
  const user = await authenticate(req);
  userID = user.id;
  const raw = await req.text();
  if (raw.length>16000) throw new Error('invalid_request');
  let body;
  try { body = JSON.parse(raw); } catch { throw new Error('invalid_request'); }
  if (body === null || typeof body !== 'object' || Array.isArray(body)) throw new Error('invalid_request');
  const hash = await identity(user.email);
  await rpc('coach_reconcile',{p_user:user.id});
  await rpc('coach_wallet',{p_user:user.id,p_identity:hash});
  let conversation = body.conversation_id;
  if (conversation != null && !uuid(conversation)) throw new Error('invalid_request');
  const config = await purchaseConfig();
  if (body.action === 'consent') await db(`coach_accounts?user_id=eq.${user.id}`, 'PATCH', { consent_at: body.accepted === true ? new Date().toISOString() : null });
  else if (body.action === 'delete_account') {
   await rpc('coach_begin_delete',{p_user:user.id});
   // When this project's sign-ins are shared with another product, erase the Coach data but keep the sign-in.
   try { if (Deno.env.get('COACH_KEEP_AUTH_USER') === 'true') await rpc('coach_erase',{p_user:user.id}); else await removeAuthUser(user.id); }
   catch (error) { await db(`coach_accounts?user_id=eq.${user.id}`,'PATCH',{deleting:false}); throw new Error('delete_unavailable'); }
   return json({ deleted:true });
  } else if (body.action === 'delete_conversation') {
   if (!uuid(conversation)) throw new Error('invalid_request');
   await rpc('coach_delete_conversation',{p_user:user.id,p_conversation:conversation});
   conversation=null;
  } else if (body.action === 'chat') {
   if (!uuid(body.request_id) || !uuid(conversation) || typeof body.question!=='string' || body.question.trim().length<1 || body.question.length>1600 || (body.context != null && (typeof body.context!=='string'||body.context.length>2400))) throw new Error('invalid_request');
   requestID=body.request_id;
   if (!Deno.env.get('OPENAI_API_KEY')) throw new Error('coach_not_ready');
   await syncPurchases(user.id);
   const turn = await rpc('coach_reserve',{p_user:user.id,p_identity:hash,p_id:requestID,p_conversation:conversation,p_question:body.question.trim(),p_context:body.context ?? ''});
   if (turn.new === true) {
    reserved=true;
    const history = await db(`coach_turns?user_id=eq.${user.id}&conversation_id=eq.${conversation}&status=eq.complete&select=question,answer&order=created_at.desc&limit=6`);
    const text=await answer(turn.question,turn.context,history.reverse());
    const settled=await rpc('coach_settle',{p_user:user.id,p_id:requestID,p_answer:text});
    reserved=false;
    if(settled.status!=='complete') throw new Error('provider_unavailable');
   }
  } else if (!['bootstrap','sync','history'].includes(body.action)) throw new Error('invalid_request');
  if (body.action!=='chat') await syncPurchases(user.id);
  const wallet=await rpc('coach_wallet',{p_user:user.id,p_identity:hash});
  const conversations=await rpc('coach_conversations',{p_user:user.id});
  const pending = await db(`coach_turns?user_id=eq.${user.id}&status=eq.pending&select=*&limit=1`);
  conversation=conversation ?? pending[0]?.conversation_id ?? conversations[0]?.id ?? crypto.randomUUID();
  const turns=await db(`coach_turns?user_id=eq.${user.id}&conversation_id=eq.${conversation}&select=id,conversation_id,question,answer,context,status,created_at&order=created_at.desc&limit=80`);
  return json({wallet,conversations,conversation_id:conversation,turns:turns.reverse(),ai_ready:Boolean(Deno.env.get('OPENAI_API_KEY')),packs_available:config.available,enabled_products:config.products});
 } catch (error) {
  if (reserved && userID && requestID) {
   try { await rpc('coach_settle',{p_user:userID,p_id:requestID,p_answer:null}); } catch { /* Expired reservations reconcile under the same account lock. */ }
  }
  const code=error instanceof Error ? error.message : '';
  return json({error:messages[code] ?? 'Coach is temporarily unavailable. Refresh to recover any reply already saved. You will not be charged twice.',code:messages[code]?code:'unavailable'},code==='sign_in_required'?401:code==='no_credits'?402:code==='rate_limit'?429:['invalid_request','request_conflict','request_deleted','consent_required','verified_email_required'].includes(code)?400:503);
 }
});
