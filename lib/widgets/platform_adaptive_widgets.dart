import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../utils/platform_utils.dart';

class PlatformAdaptiveButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color? color;
  final bool isDestructive;

  const PlatformAdaptiveButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.color,
    this.isDestructive = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.isIOS) {
      return CupertinoButton(
        onPressed: onPressed,
        color: isDestructive ? CupertinoColors.destructiveRed : (color ?? CupertinoColors.activeBlue),
        child: Text(text),
      );
    } else {
      return ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDestructive ? Colors.red : (color ?? const Color(0xFF7E5EFD)),
        ),
        child: Text(text),
      );
    }
  }
}

class PlatformAdaptiveDialog extends StatelessWidget {
  final String title;
  final String content;
  final List<PlatformAdaptiveDialogAction> actions;

  const PlatformAdaptiveDialog({
    Key? key,
    required this.title,
    required this.content,
    required this.actions,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.isIOS) {
      return CupertinoAlertDialog(
        title: Text(title),
        content: Text(content),
        actions: actions.map((action) => CupertinoDialogAction(
          onPressed: action.onPressed,
          isDestructiveAction: action.isDestructive,
          child: Text(action.text),
        )).toList(),
      );
    } else {
      return AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: actions.map((action) => TextButton(
          onPressed: action.onPressed,
          child: Text(
            action.text,
            style: TextStyle(
              color: action.isDestructive ? Colors.red : null,
            ),
          ),
        )).toList(),
      );
    }
  }
}

class PlatformAdaptiveDialogAction {
  final String text;
  final VoidCallback? onPressed;
  final bool isDestructive;

  PlatformAdaptiveDialogAction({
    required this.text,
    this.onPressed,
    this.isDestructive = false,
  });
}

class PlatformAdaptiveLoading extends StatelessWidget {
  const PlatformAdaptiveLoading({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.isIOS) {
      return const CupertinoActivityIndicator();
    } else {
      return const CircularProgressIndicator();
    }
  }
}

class PlatformAdaptiveSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const PlatformAdaptiveSwitch({
    Key? key,
    required this.value,
    this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.isIOS) {
      return CupertinoSwitch(
        value: value,
        onChanged: onChanged,
      );
    } else {
      return Switch(
        value: value,
        onChanged: onChanged,
      );
    }
  }
}