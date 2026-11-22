-- BALLAL — 0009 : réduit qui peut appeler quoi (alertes du conseiller sécurité Supabase)

-- Fonctions de déclencheur : jamais appelables via l'API.
revoke execute on function
  public.handle_new_user(), public.handle_user_phone_confirmed(),
  public.message_before_insert(), public.message_after_insert(),
  public.pro_before_write(), public.pro_refresh_from_child(),
  public.report_before_insert(), public.request_before_insert(), public.request_after_write(),
  public.review_after_write(), public.review_reply_after_insert()
from public, anon, authenticated;

-- Fonctions réservées aux utilisateurs connectés (elles vérifient aussi auth.uid() en interne).
revoke execute on function
  public.activate_role(public.app_role),
  public.admin_moderate_review(uuid, public.review_status, text),
  public.admin_resolve_report(uuid, public.report_status, text),
  public.admin_review_verification(uuid, public.doc_status, text),
  public.admin_set_user_status(uuid, public.account_status, text),
  public.grant_staff_role(uuid, public.app_role),
  public.revoke_staff_role(uuid, public.app_role),
  public.count_my_followers(), public.delete_my_account(),
  public.get_professional_contact(uuid), public.get_unread_counts(),
  public.list_my_conversations(int, timestamptz), public.log_recommendation_event(uuid, public.reco_action, int, jsonb),
  public.mark_conversation_read(uuid), public.record_profile_view(uuid),
  public.report_content(public.report_target, uuid, text, text, uuid[]),
  public.start_conversation(uuid, uuid),
  public.update_request_status(uuid, public.request_status, text),
  public.can_send_message(uuid), public.is_conversation_member(uuid), public.is_blocked_between(uuid, uuid),
  public.has_role(public.app_role), public.is_active_user(), public.is_user_active(uuid)
from public, anon;

grant execute on function
  public.activate_role(public.app_role),
  public.admin_moderate_review(uuid, public.review_status, text),
  public.admin_resolve_report(uuid, public.report_status, text),
  public.admin_review_verification(uuid, public.doc_status, text),
  public.admin_set_user_status(uuid, public.account_status, text),
  public.grant_staff_role(uuid, public.app_role),
  public.revoke_staff_role(uuid, public.app_role),
  public.count_my_followers(), public.delete_my_account(),
  public.get_professional_contact(uuid), public.get_unread_counts(),
  public.list_my_conversations(int, timestamptz), public.log_recommendation_event(uuid, public.reco_action, int, jsonb),
  public.mark_conversation_read(uuid), public.record_profile_view(uuid),
  public.report_content(public.report_target, uuid, text, text, uuid[]),
  public.start_conversation(uuid, uuid),
  public.update_request_status(uuid, public.request_status, text),
  public.can_send_message(uuid), public.is_conversation_member(uuid), public.is_blocked_between(uuid, uuid),
  public.has_role(public.app_role), public.is_active_user(), public.is_user_active(uuid)
to authenticated;

-- Restent publics volontairement (visiteurs sans compte) : search_professionals, recommend_professionals,
-- et les helpers utilisés par les politiques de lecture publiques : is_public_pro, can_view_profile,
-- is_staff, is_admin, pro_serves_location, f_norm, haversine_km.
