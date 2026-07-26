/// Widget Key strings used by Appium automation (see /greenroot-e2e).
///
/// Mirrored 1:1 in greenroot-e2e/src/constants/testKeys.ts — keep both in
/// sync. Bottom-nav tab keys are generated dynamically as
/// `nav_tab_<label.toLowerCase()>` in app/main_shell.dart rather than
/// listed here, since they're derived from existing tab labels.
class TestKeys {
  TestKeys._();

  // Auth — login screen
  static const loginMobileField = 'login_mobile_field';
  static const loginAgreeCheckbox = 'login_agree_checkbox';
  static const loginSendOtpButton = 'login_send_otp_button';

  // Auth — OTP screen
  static const otpCodeField = 'otp_code_field';
  static const otpVerifyButton = 'otp_verify_button';

  // Commerce lists and lifecycle
  static const quotationList = 'quotation_list';
  static const orderList = 'order_list';
  static const orderCreateButton = 'order_create_button';
  static const dispatchList = 'dispatch_list';
  static const dispatchFilterAll = 'dispatch_filter_all';
  static const dispatchFilterPending = 'dispatch_filter_pending';
  static const dispatchFilterDispatched = 'dispatch_filter_dispatched';
  static const dispatchFilterInTransit = 'dispatch_filter_in_transit';
  static const dispatchFilterDelivered = 'dispatch_filter_delivered';
  static const dispatchDetail = 'dispatch_detail';
  static const dispatchCreateDestination = 'dispatch_create_destination';
  static const dispatchCreateNotes = 'dispatch_create_notes';
  static const dispatchCreateSubmit = 'dispatch_create_submit';

  // Owner members and invite acceptance
  static const membersScreen = 'members_screen';
  static const membersManagersTab = 'members_managers_tab';
  static const membersDriversTab = 'members_drivers_tab';
  static const membersCustomersTab = 'members_customers_tab';
  static const inviteManagerButton = 'invite_manager_button';
  static const inviteCustomerButton = 'invite_customer_button';
  static const inviteCodeField = 'invite_code_field';
  static const inviteLookupButton = 'invite_lookup_button';
  static const inviteAcceptButton = 'invite_accept_button';
}
