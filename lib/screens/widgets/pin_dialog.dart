
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colorScheme.surface,
              colorScheme.surface.withOpacity(0.95),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: colorScheme.outlineVariant.withOpacity(0.5),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        padding: const EdgeInsets.all(28),
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.isSettingPin ? Icons.lock_outline : Icons.lock_open_outlined,
                size: 32,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            
            // Title
            Text(
              widget.isSettingPin && _firstPin != null ? _message : widget.title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            
            // Error/Info Message
            if (_message.isNotEmpty && (!widget.isSettingPin || _firstPin == null)) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _error 
                      ? colorScheme.errorContainer.withOpacity(0.5)
                      : colorScheme.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _message,
                  style: TextStyle(
                    color: _error ? colorScheme.error : colorScheme.onSurfaceVariant,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const SizedBox(height: 32),
            
            // PIN Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final isFilled = index < _currentPin.length;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFilled
                        ? colorScheme.primary
                        : colorScheme.surfaceVariant,
                    border: Border.all(
                      color: isFilled 
                          ? colorScheme.primary
                          : colorScheme.outline.withOpacity(0.5),
                      width: 2,
                    ),
                    boxShadow: isFilled ? [
                      BoxShadow(
                        color: colorScheme.primary.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ] : null,
                  ),
                );
              }),
            ),
            const SizedBox(height: 40),
            
            // Keypad
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              childAspectRatio: 1.2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [
                ...List.generate(9, (index) => _buildKey('${index + 1}')),
                const SizedBox(), // Empty space
                _buildKey('0'),
                _buildDeleteKey(),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Cancel Button
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKey(String val) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onDigitPress(val),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer.withOpacity(0.4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outline.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Text(
            val,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildDeleteKey() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _onDelete,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colorScheme.errorContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outline.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Icon(
            Icons.backspace_outlined,
            color: colorScheme.error,
            size: 24,
          ),
        ),
      ),
    );
  }
}
