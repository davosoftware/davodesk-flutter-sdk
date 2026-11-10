# The contact form and its subjects (Flutter SDK) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** the form that raises a ticket loses the word "email" (as words and as names), and its Subject offers the brand's request subjects while still taking the customer's own words.

**Architecture:** renames through the SDK (`DavoDeskEmailForm` → `DavoDeskContactForm`, `DavoDeskPage.email` → `.contact`, `EmailPlace` → `ContactPlace`, `features/email` → `features/contact`), then `ChannelConfig.requestSubjects`, `raiseTicket(subjectKey:)` in the API service and the client, and a filtering `DropdownMenu` for Subject.

**Tech Stack:** Flutter 3.47 / Dart 3.13, `material_ui`, widget tests.

**Spec:** `support-api/docs/superpowers/specs/2026-11-10-request-subjects-design.md`.

**Depends on:** support-api `docs/superpowers/plans/2026-11-10-request-subjects.md`, merged (for the run on the emulator).

## Global Constraints

- **Words, exactly:** title "Send us a message"; no "Email Us" heading; intro "Have a question about your order or our services? Our team is here to help."; Subject hint "What can we help you with?"; button "Send"; after sending "Sent. We'll reply in Messages."; "Added to your open request #REF" unchanged. The example app's note: "We typically respond within 24 hours."; its button "Send us a message".
- The subject's key is sent only while the field holds that subject's label exactly (trimmed); otherwise no key.
- A brand with no subjects keeps a plain text field.
- Everything in the earlier SDK plans' Global Constraints still applies (material_ui only, strict analysis, `dart fix` and `dart format` before commits).
- Commits as Hyacinth-Chidi, no Co-Authored-By trailer; worktree `../worktrees/davodesk-flutter-contact-form`, branch `feat/contact-form`; merge with `--no-ff`, never push.

## Review Focus

1. **Picking a subject, then editing it:** no key is sent. Test: Task 2.
2. **200 % text** with the dropdown open: nothing overflows. Test: Task 2.

---

### Task 1: "Send us a message", with no "email"

**Files:**
- Rename and modify: `lib/src/ui/features/email/` → `lib/src/ui/features/contact/` (`ContactPage`, `ContactViewModel`), `EmailPlace` → `ContactPlace` and `emailForm` → `contactForm` in `lib/src/ui/core/scope.dart`, `DavoDeskEmailForm` → `DavoDeskContactForm` in `lib/src/ui/theme.dart`, `DavoDeskPage.email` → `.contact` and `emailForm:` → `contactForm:` in `lib/src/davodesk.dart`, `lib/davodesk_flutter.dart`, `lib/src/ui/previews.dart`, `README.md`.
- Modify: `example_app/lib/main.dart`, `example_app/lib/acme_home.dart`.
- Test: `test/ui/email_page_test.dart` → `test/ui/contact_page_test.dart`, `test/support/pages.dart`, `test/davodesk_test.dart`, `example_app/test/widget_test.dart`.

- [ ] **Step 1: Update the tests to the new words and names** (a ruling: the owner changed the words, 2026-11-10).
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `flutter test` and `flutter analyze` in both folders. Expected: PASS and clean. **Commit** `feat(sdk): Send us a message, with no "email"`.

### Task 2: Subjects to pick from, or the customer's own

**Files:**
- Modify: `lib/src/domain/models.dart` (`RequestSubject(key, label)`, `ChannelConfig.requestSubjects`), `lib/src/data/services/api_service.dart` (`raiseTicket(..., subjectKey)`), `lib/src/client.dart` (`raiseTicket(..., subjectKey)`), the contact page and view model.
- Test: `test/data/services/api_service_test.dart`, `test/client_test.dart`, `test/ui/contact_page_test.dart`, `test/support/fake_api.dart`.

- [ ] **Step 1: Write the failing tests:**
  - the config reads `request_subjects`, and a missing list is empty;
  - `raiseTicket` sends `subject_key` only when given;
  - with subjects, tapping Subject shows them; picking one and sending sends its label and key;
  - typing a subject of one's own sends no key; picking one then editing it sends no key;
  - with no subjects, Subject is a plain text field;
  - nothing overflows at 200 % text with the list open.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `flutter test` and `flutter analyze`. Expected: PASS and clean. **Commit** `feat(sdk): the brand's request subjects on the contact form`, then self-review, merge `--no-ff`, don't push, and re-run the emulator check of the form.
