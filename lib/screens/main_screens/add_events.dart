import 'package:bottom_picker/bottom_picker.dart';
import 'package:bottom_picker/resources/arrays.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final List<String> _events = [
    "Coffee",
    "Dog walking",
    "Team Meeting",
    "Learning Session",
    "Gym Training",
    "Evening Walk",
    "Cooking",
    "Meditation",
    "Reading",
    "Evening walk",
    "Task",
  ];

  Future<void> _selectTimeframe(BuildContext context, String event) async {
    BottomPicker.rangeTime(
      headerBuilder: (context) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select time range for',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.black,
              ),
            ),
            Text(
              '$event',
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ],
        );
      },
      dismissable: true,
      showTimeSeparator: true,
      use24hFormat: true,
      bottomPickerTheme: BottomPickerTheme.orange,

      // THIS callback is required for time range
      onRangeTimeSubmitPressed: (DateTime start, DateTime end) {
        final startText = TimeOfDay.fromDateTime(start).format(context);
        final endText = TimeOfDay.fromDateTime(end).format(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Selected $startText – $endText for $event')),
        );
      },

      onRangePickerDismissed: (start, end) {
        // Optional: handle dismiss
      },
    ).show(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          const Padding(
            padding: EdgeInsets.only(left: 24.0, bottom: 16.0),
            child: Text(
              'Events',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                fontFamily: 'Montserrat',
                color: Colors.black87,
              ),
            ),
          ),
          // The GridView handles scrolling automatically
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, // 3 cards per row
                crossAxisSpacing: 15,
                mainAxisSpacing: 20,
                childAspectRatio: 1 / 1.3, // width : height ratio
              ),
              itemCount: _events.length,
              itemBuilder: (context, index) {
                final event = _events[index];
                return GestureDetector(
                  onTap: () => _selectTimeframe(context, event),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFF09819), Color(0xFFEDDE5D)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          const Icon(
                            Icons.event,
                            size: 32,
                            color: Colors.white,
                          ),
                          Flexible(
                            child: Text(
                              event,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Montserrat',
                                color: Colors.white,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => _selectTimeframe(context, event),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Color(0xFFf7b733),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              minimumSize: const Size(
                                0,
                                32,
                              ), // reduces the button height
                              textStyle: const TextStyle(fontSize: 12),
                              tapTargetSize:
                                  MaterialTapTargetSize
                                      .shrinkWrap, // removes extra space
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('Select'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }
}
