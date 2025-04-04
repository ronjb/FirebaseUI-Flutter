// Copyright 2022, the Chromium project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:firebase_auth/firebase_auth.dart' as fba;
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:firebase_ui_localizations/firebase_ui_localizations.dart';
import 'package:firebase_ui_shared/firebase_ui_shared.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

typedef DeleteFailedCallback = void Function(Exception exception);
typedef SignInRequiredCallback = Future<bool> Function();

/// {@template ui.auth.widgets.delete_account_button}
/// A button that triggers the deletion of the user's account.
///
/// If you want to perform an action after the account is deleted, you can
/// use [AccountDeletedAction].
///
/// Example usage:
/// ```dart
/// ProfileScreen(
///   actions: [
///     AccountDeletedAction((context, user) {
///       // Do something after the account is deleted.
///     }),
///   ],
/// );
/// ```
///
/// or
///
/// ```dart
/// FirebaseUIActions(
///   actions: [
///     AccountDeletedAction((context, user) {
///       // Do something after the account is deleted.
///     }),
///   ],
///   // MyCustomScreen should use DeleteAccountButton internally.
///   child: MyCustomScreen(),
/// )
/// ```
/// {@endtemplate}
class DeleteAccountButton extends StatefulWidget {
  /// {@macro ui.auth.auth_controller.auth}
  final fba.FirebaseAuth? auth;

  /// A callback tha is called if the [FirebaseAuth] requires the user to
  /// re-authenticate and approve the account deletion. By default,
  /// [ReauthenticateDialog] is being shown.
  final SignInRequiredCallback? onSignInRequired;

  /// A callback that is called right before `auth.currentUser?.delete()`
  /// is called.
  final void Function(String userId)? onDeletingAccount;

  /// A callback that is called if the account deletion fails.
  final DeleteFailedCallback? onDeleteFailed;

  /// {@macro ui.shared.widgets.button_variant}
  final ButtonVariant variant;

  /// {@template ui.auth.widgets.delete_account_button.show_delete_confirmation_dialog}
  /// If `true`, the user will be asked to confirm the account deletion.
  /// {@endtemplate}
  final bool showDeleteConfirmationDialog;

  /// {@macro ui.auth.widgets.delete_account_button}
  const DeleteAccountButton({
    super.key,
    this.auth,
    this.onSignInRequired,
    this.onDeletingAccount,
    this.onDeleteFailed,
    this.variant = ButtonVariant.filled,
    this.showDeleteConfirmationDialog = false,
  });

  @override
  // ignore: library_private_types_in_public_api
  _DeleteAccountButtonState createState() => _DeleteAccountButtonState();
}

class _DeleteAccountButtonState extends State<DeleteAccountButton> {
  fba.FirebaseAuth get auth => widget.auth ?? fba.FirebaseAuth.instance;
  bool _isLoading = false;

  Future<void> _deleteAccount() async {
    bool confirmed = !widget.showDeleteConfirmationDialog;

    if (!confirmed) {
      final l = FirebaseUILocalizations.labelsOf(context);
      confirmed = await showDialog<bool>(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: Text(l.confirmDeleteAccountAlertTitle),
                content: Text(l.confirmDeleteAccountAlertMessage),
                actions: [
                  TextButton(
                    child: Text(l.cancelButtonLabel),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                  TextButton(
                    child: Text(l.confirmDeleteAccountButtonLabel,
                        style: const TextStyle(color: Colors.red)),
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ],
              );
            },
          ) ??
          false;
    }

    if (!confirmed) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = auth.currentUser!;
      widget.onDeletingAccount?.call(user.uid);
      await auth.currentUser?.delete();

      FirebaseUIAction.ofType<AccountDeletedAction>(context)?.callback(
        context,
        user,
      );
      await FirebaseUIAuth.signOut(context: context, auth: auth);
    } on fba.FirebaseAuthException catch (err) {
      if (err.code == 'requires-recent-login') {
        if (widget.onSignInRequired != null) {
          final signedIn = await widget.onSignInRequired!();
          if (signedIn) {
            await _deleteAccount();
          }
        }
      }
    } on Exception catch (e) {
      widget.onDeleteFailed?.call(e);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = FirebaseUILocalizations.labelsOf(context);

    final themeData = Theme.of(context);
    final colorScheme = themeData.colorScheme;

    return LoadingButton(
      isLoading: _isLoading,
      cupertinoColor: CupertinoColors.destructiveRed,
      materialColor: colorScheme.error,
      cupertinoIcon: CupertinoIcons.delete,
      materialIcon: Icons.delete,
      label: l.deleteAccount,
      labelColor: colorScheme.onError,
      onTap: _deleteAccount,
      variant: widget.variant,
    );
  }
}
