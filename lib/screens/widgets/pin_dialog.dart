
import 'package:flutter/material.dart';
import '../../services/pin_service.dart';

class PinDialog extends StatefulWidget {
  final bool isSettingPin; // If true, we are setting a new PIN
  final String title;

  const PinDialog({
    super.key, 
    this.isSettingPin = false,
    this.title = 'Enter PIN',
  });

  @override
  State<PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<PinDialog> {
  String _currentPin = '';
  String? _firstPin; // Used when setting a PIN to confirm
  String _message = '';
  bool _error = false;

  void _onDigitPress(String digit) {
    setState(() {
      if (_currentPin.length < 4) {
        _currentPin += digit;
        _error = false;
        
        if (_currentPin.length == 4) {
          _onSubmit();
        }
      }
    });
  }

  void _onDelete() {
    setState(() {
      if (_currentPin.isNotEmpty) {
        _currentPin = _currentPin.substring(0, _currentPin.length - 1);
        _error = false;
      }
    });
  }

  Future<void> _onSubmit() async {
    if (widget.isSettingPin) {
      if (_firstPin == null) {
        // First entry done, ask for confirmation
        setState(() {
          _firstPin = _currentPin;
          _currentPin = '';
          _message = 'Confirm PIN';
        });
      } else {
        // Confirmation entry
        if (_currentPin == _firstPin) {
          // Match!
          await PinService().setPin(_currentPin);
          if (mounted) Navigator.pop(context, true);
        } else {
          // Mismatch
          setState(() {
            _currentPin = '';
            _firstPin = null;
            _message = 'PINs do not match. Try again.';
            _error = true;
          });
        }
      }
    } else {
      // Verifying PIN
      final isValid = await PinService().verify(_currentPin);
      if (isValid) {
        if (mounted) Navigator.pop(context, true);
      } else {
        setState(() {
          _currentPin = '';
          _message = 'Incorrect PIN';
          _error = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.isSettingPin && _firstPin != null ? _message : widget.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (_message.isNotEmpty && (!widget.isSettingPin || _firstPin == null)) ...[
              const SizedBox(height: 8),
              Text(
                _message,
                style: TextStyle(
                  color: _error ? Colors.red : Colors.grey,
                  fontSize: 14,
                ),
              ),
            ],
            const SizedBox(height: 24),
            
            // PIN Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index < _currentPin.length
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surfaceVariant,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 1,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 32),
            
            // Keypad
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              childAspectRatio: 1.5,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: [
                ...List.generate(9, (index) => _buildKey('${index + 1}')),
                const SizedBox(), // Empty
                _buildKey('0'),
                IconButton(
                  onPressed: _onDelete,
                  icon: const Icon(Icons.backspace_outlined),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKey(String val) {
    return InkWell(
      onTap: () => _onDigitPress(val),
      borderRadius: BorderRadius.circular(50),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.3),
        ),
        child: Text(
          val,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
