import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

class TwoFactorAuthScreen extends StatefulWidget {
  const TwoFactorAuthScreen({Key? key}) : super(key: key);

  @override
  State<TwoFactorAuthScreen> createState() => _TwoFactorAuthScreenState();
}

class _TwoFactorAuthScreenState extends State<TwoFactorAuthScreen> {
  int _currentStep = 0; // 0 = Phone Input, 1 = OTP Verification

  // Step 1: Phone Number
  final TextEditingController _phoneController = TextEditingController();
  String _selectedCountryCode = '+94';
  final List<CountryCode> _countryCodes = [
    CountryCode(code: '+94', name: 'Sri Lanka', flag: '🇱🇰'),
    CountryCode(code: '+1', name: 'USA', flag: '🇺🇸'),
    CountryCode(code: '+44', name: 'UK', flag: '🇬🇧'),
    CountryCode(code: '+91', name: 'India', flag: '🇮🇳'),
    CountryCode(code: '+61', name: 'Australia', flag: '🇦🇺'),
    CountryCode(code: '+971', name: 'UAE', flag: '🇦🇪'),
  ];

  // Step 2: OTP
  final List<TextEditingController> _otpControllers =
  List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _otpFocusNodes =
  List.generate(6, (index) => FocusNode());

  Timer? _timer;
  int _remainingSeconds = 60;
  bool _canResend = false;
  bool _isVerifying = false;
  bool _verificationSuccess = false;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _otpFocusNodes) {
      node.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _remainingSeconds = 60;
    _canResend = false;
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _canResend = true;
          timer.cancel();
        }
      });
    });
  }

  void _sendCode() {
    if (_phoneController.text.isEmpty || _phoneController.text.length < 9) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('කරුණාකර වලංගු දුරකථන අංකයක් ඇතුළත් කරන්න'),
          backgroundColor: Color(0xFFDC143C),
        ),
      );
      return;
    }

    setState(() {
      _currentStep = 1;
    });
    _startTimer();

    // Simulate sending SMS
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'SMS කේතය $_selectedCountryCode${_phoneController.text} වෙත යවන ලදී',
        ),
        backgroundColor: const Color(0xFF4CAF50),
      ),
    );
  }

  void _resendCode() {
    setState(() {
      _errorMessage = null;
      for (var controller in _otpControllers) {
        controller.clear();
      }
    });
    _startTimer();
    _otpFocusNodes[0].requestFocus();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('නව SMS කේතය යවන ලදී'),
        backgroundColor: Color(0xFF4CAF50),
      ),
    );
  }

  void _verifyOTP() async {
    final otp = _otpControllers.map((c) => c.text).join();

    if (otp.length != 6) {
      setState(() {
        _errorMessage = 'කරුණාකර අංක 6ම ඇතුළත් කරන්න';
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    // Simulate API call
    await Future.delayed(const Duration(seconds: 2));

    // For demo: accept "123456" as valid
    if (otp == '123456') {
      setState(() {
        _verificationSuccess = true;
        _isVerifying = false;
      });

      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('2FA සාර්ථකව සක්‍රිය කරන ලදී! ✓'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
      }
    } else {
      setState(() {
        _isVerifying = false;
        _errorMessage = 'වැරදි කේතයකි. නැවත උත්සාහ කරන්න.';
      });

      // Clear OTP fields on error
      for (var controller in _otpControllers) {
        controller.clear();
      }
      _otpFocusNodes[0].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F1F1F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A2A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Two-Factor Authentication',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Security Lock Icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF4CAF50),
                  width: 3,
                ),
              ),
              child: const Icon(
                Icons.lock_outline,
                color: Color(0xFF4CAF50),
                size: 50,
              ),
            ),

            const SizedBox(height: 24),

            // Title
            Text(
              _currentStep == 0 ? 'Secure Your Account' : 'Enter Verification Code',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 12),

            // Description
            Text(
              _currentStep == 0
                  ? 'අපි ඔබගේ ගිණුමේ ආරක්ෂාව තහවුරු කිරීමට SMS කේතයක් එවන්නෙමු'
                  : 'ඔබගේ දුරකථනයට එවන ලද 6 ඉලක්කම් කේතය ඇතුළත් කරන්න',
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 15,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 40),

            // Step Content
            _currentStep == 0 ? _buildPhoneInputStep() : _buildOTPVerificationStep(),

            const SizedBox(height: 24),

            // Privacy Note
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF3A3A3A)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.privacy_tip_outlined,
                    color: Color(0xFF2196F3),
                    size: 20,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'ඔබේ අංකය කිසිවෙකුට ප්‍රසිද්ධ නොකරනු ඇත',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Step 1: Phone Number Input
  Widget _buildPhoneInputStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'දුරකථන අංකය',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 12),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Country Code Dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF3A3A3A)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCountryCode,
                  dropdownColor: const Color(0xFF2A2A2A),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  items: _countryCodes.map((country) {
                    return DropdownMenuItem<String>(
                      value: country.code,
                      child: Row(
                        children: [
                          Text(country.flag, style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 8),
                          Text(country.code),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCountryCode = value!;
                    });
                  },
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Phone Number Input
            Expanded(
              child: TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: InputDecoration(
                  hintText: '771234567',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF2A2A2A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF3A3A3A)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF3A3A3A)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF4CAF50),
                      width: 2,
                    ),
                  ),
                  prefixIcon: const Icon(
                    Icons.phone_android,
                    color: Colors.white70,
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 32),

        // Send Code Button
        ElevatedButton(
          onPressed: _sendCode,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4CAF50),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.send, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Text(
                'Send Code',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Step 2: OTP Verification
  Widget _buildOTPVerificationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Phone number display
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.phone_android, color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Text(
                '$_selectedCountryCode ${_phoneController.text}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _currentStep = 0;
                    _timer?.cancel();
                  });
                },
                child: const Icon(
                  Icons.edit,
                  color: Color(0xFF2196F3),
                  size: 18,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // OTP Input Boxes
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(6, (index) {
            return SizedBox(
              width: 50,
              height: 60,
              child: TextFormField(
                controller: _otpControllers[index],
                focusNode: _otpFocusNodes[index],
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 1,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: const Color(0xFF2A2A2A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: _errorMessage != null
                          ? const Color(0xFFDC143C)
                          : const Color(0xFF3A3A3A),
                      width: 2,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: _errorMessage != null
                          ? const Color(0xFFDC143C)
                          : const Color(0xFF3A3A3A),
                      width: 2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF4CAF50),
                      width: 2,
                    ),
                  ),
                ),
                onChanged: (value) {
                  if (value.isNotEmpty && index < 5) {
                    _otpFocusNodes[index + 1].requestFocus();
                  } else if (value.isEmpty && index > 0) {
                    _otpFocusNodes[index - 1].requestFocus();
                  }

                  // Auto-verify when all 6 digits entered
                  if (index == 5 && value.isNotEmpty) {
                    _verifyOTP();
                  }

                  setState(() {
                    _errorMessage = null;
                  });
                },
              ),
            );
          }),
        ),

        const SizedBox(height: 16),

        // Error Message
        if (_errorMessage != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2A0A0A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFDC143C)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Color(0xFFDC143C), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Color(0xFFDC143C),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Success Animation
        if (_verificationSuccess)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0A2A0A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFF3B5C ), width: 2),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: Color(0xFFFF3B5C ), size: 32),
                SizedBox(width: 12),
                Text(
                  'Verification Successful!',
                  style: TextStyle(
                    color: Color(0xFFFF3B5C ),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 24),

        // Timer and Resend
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!_canResend) ...[
              const Icon(Icons.schedule, color: Colors.white60, size: 18),
              const SizedBox(width: 8),
              Text(
                '00:${_remainingSeconds.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ] else ...[
              TextButton(
                onPressed: _resendCode,
                child: const Row(
                  children: [
                    Icon(Icons.refresh, color: Color(0xFF2196F3), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Resend Code',
                      style: TextStyle(
                        color: Color(0xFF2196F3),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),

        const SizedBox(height: 16),

        // Verify Button
        ElevatedButton(
          onPressed: _isVerifying ? null : _verifyOTP,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF3B5C),
            disabledBackgroundColor: const Color(0xFF3A3A3A),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
          ),
          child: _isVerifying
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          )
              : const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.verified_user, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Text(
                'Verify Code',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Country Code Model
class CountryCode {
  final String code;
  final String name;
  final String flag;

  CountryCode({
    required this.code,
    required this.name,
    required this.flag,
  });
}