import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:setup/auth/application/auth_controller.dart';
import 'package:setup/auth/data/firebase_auth_repository_providers.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  // Track expanded state for each card
  final List<bool> _expanded = [false, false, false];

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(firebaseUserProvider);
    final displayName = user?.displayName ?? 'Guest';

    final email = user?.email ?? '';

    final photoUrl = user?.photoURL ?? 'https://i.pravatar.cc/150?img=3';

    print(email);

    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(top: 32.0), // Optional: space from top
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch, // Ensures horizontal stretch
            mainAxisAlignment: MainAxisAlignment.start, // Aligns from the top
            children: [
              // Title at the top
              const Padding(
                padding: EdgeInsets.only(left: 24.0, bottom: 8.0),
                child: Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Montserrat',
                    color: Colors.black87,
                  ),
                ),
              ),
              // Expandable Cards
              ...List.generate(_expanded.length, (index) {
                final titles = [
                  'Account Settings',
                  'Manage Subscription',
                  'Feedback',
                ];
                final icons = [
                  Icons.person, // Account Settings
                  Icons.subscriptions, // Manage Subscription
                  Icons.feedback, // Feedback
                ];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 8.0,
                  ), // <-- Add horizontal padding here
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _expanded[index] = !_expanded[index];
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      width: MediaQuery.of(context).size.width - 40,
                      height: _expanded[index] ? (index == 0 ? 320 : 200) : 60,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Align(
                          alignment: Alignment.topLeft,
                          child:
                              _expanded[index]
                                  ? (index == 0
                                      ? SingleChildScrollView(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment
                                                  .start, // <-- Align content to top/left
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 16.0,
                                                left: 16.0,
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    icons[index],
                                                    color: Colors.black54,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  const Text(
                                                    'Account Settings',
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            Row(
                                              children: [
                                                const SizedBox(width: 16),
                                                CircleAvatar(
                                                  radius: 30,
                                                  backgroundImage: NetworkImage(
                                                    photoUrl,
                                                  ),
                                                ),
                                                const SizedBox(width: 16),
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      email,
                                                      style: const TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    ElevatedButton(
                                                      onPressed: () {},
                                                      child: const Text(
                                                        'Edit your profile',
                                                      ),
                                                      style:
                                                          ElevatedButton.styleFrom(
                                                            minimumSize:
                                                                const Size(
                                                                  120,
                                                                  32,
                                                                ),
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 16),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16.0,
                                                  ),
                                              child: Column(
                                                children: [
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      const Text(
                                                        'Enable Push Notifications',
                                                      ),
                                                      Switch(
                                                        value: true,
                                                        onChanged: (val) {},
                                                      ),
                                                    ],
                                                  ),
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      const Text('Dark Mode'),
                                                      Switch(
                                                        value: false,
                                                        onChanged: (val) {},
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                      : SingleChildScrollView(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment
                                                  .start, // <-- Align content to top/left
                                          children: [
                                            Row(
                                              children: [
                                                Icon(
                                                  icons[index],
                                                  color: Colors.black54,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  titles[index],
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 16),
                                            if (index == 1)
                                              ElevatedButton(
                                                onPressed: () {
                                                  // Handle manage subscription
                                                },
                                                child: const Text(
                                                  'Manage your subscription',
                                                ),
                                              ),
                                            if (index == 2)
                                              ElevatedButton(
                                                onPressed: () {
                                                  // Handle feedback
                                                },
                                                child: const Text(
                                                  'Send Feedback',
                                                ),
                                              ),
                                          ],
                                        ),
                                      ))
                                  : Padding(
                                    padding: const EdgeInsets.all(18.0),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                left: 16.0,
                                              ),
                                              child: Icon(
                                                icons[index],
                                                color: Colors.black54,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              titles[index],
                                              style: const TextStyle(
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const Padding(
                                          padding: EdgeInsets.only(right: 16.0),
                                          child: Icon(
                                            Icons.arrow_forward_ios,
                                            size: 18,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
              // Sign Out Card (not expandable)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 8.0,
                ), // <-- Add horizontal padding here
                child: Container(
                  width:
                      double
                          .infinity, // <-- Let the card fill the available width inside the padding
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await ref
                            .read(authControllerProvider.notifier)
                            .signOut();
                      },
                      icon: const Icon(Icons.logout, color: Colors.red),
                      label: const Text(
                        'Sign Out',
                        style: TextStyle(color: Colors.red),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.red,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
