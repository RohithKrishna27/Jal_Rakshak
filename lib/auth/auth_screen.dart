import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.infoMessage});

  final String? infoMessage;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLogin = true;
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  String _selectedRole = 'user';
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      if (_isLogin) {
        final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(credential.user!.uid)
            .get();

        if (!userDoc.exists) {
          throw FirebaseAuthException(
            code: 'profile-not-found',
            message: 'No user profile exists for this account.',
          );
        }
      } else {
        final credential =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        await FirebaseFirestore.instance
            .collection('users')
            .doc(credential.user!.uid)
            .set({
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'role': _selectedRole,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = _mapAuthError(e);
      });
    } catch (_) {
      setState(() {
        _error = 'Something went wrong. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'email-already-in-use':
        return 'This email is already registered. Please log in.';
      case 'weak-password':
        return 'Password should be at least 6 characters.';
      case 'profile-not-found':
        return 'Account exists, but role profile is missing. Sign up again.';
      default:
        return e.message ?? 'Authentication failed.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE0F7FA), Color(0xFFF2FDFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Jal Rakshak',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isLogin
                              ? 'Login to continue'
                              : 'Create your account',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        if (widget.infoMessage != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            widget.infoMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.orange),
                          ),
                        ],
                        const SizedBox(height: 20),
                        if (!_isLogin) ...[
                          TextFormField(
                            controller: _nameController,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Full Name',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (value) {
                              if (_isLogin) return null;
                              if (value == null || value.trim().isEmpty) {
                                return 'Enter your name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: (value) {
                            if (value == null || !value.contains('@')) {
                              return 'Enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.length < 6) {
                              return 'Minimum 6 characters required';
                            }
                            return null;
                          },
                        ),
                        if (!_isLogin) ...[
                          const SizedBox(height: 14),
                          SegmentedButton<String>(
                            showSelectedIcon: false,
                            segments: const [
                              ButtonSegment(
                                value: 'user',
                                icon: Icon(Icons.person),
                                label: Text('Normal User'),
                              ),
                              ButtonSegment(
                                value: 'industry_admin',
                                icon: Icon(Icons.factory),
                                label: Text('Industry Admin'),
                              ),
                            ],
                            selected: {_selectedRole},
                            onSelectionChanged: (value) {
                              setState(() => _selectedRole = value.first);
                            },
                          ),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _isSubmitting ? null : _submit,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(_isLogin ? 'Login' : 'Create Account'),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _isSubmitting
                              ? null
                              : () {
                                  setState(() {
                                    _isLogin = !_isLogin;
                                    _error = null;
                                  });
                                },
                          child: Text(
                            _isLogin
                                ? "Don't have an account? Sign Up"
                                : 'Already have an account? Login',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

