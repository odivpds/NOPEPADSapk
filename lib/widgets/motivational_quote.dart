import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class MotivationalQuote extends StatefulWidget {
  final String userName;

  const MotivationalQuote({super.key, required this.userName});

  @override
  State<MotivationalQuote> createState() => _MotivationalQuoteState();
}

class _MotivationalQuoteState extends State<MotivationalQuote> {
  int _quoteIndex = 0;
  Timer? _timer;

  List<String> get _quotes => [
        '"You got this, ${widget.userName}!\nOne step at a time."',
        '"Hey ${widget.userName},\ngreat things never came\nfrom comfort zones."',
        '"Keep pushing, ${widget.userName}.\nYour future self\nwill thank you!"',
        '"${widget.userName},\ndon\'t stop until\nyou\'re proud."',
        '"Dream big, work hard,\nstay focused, ${widget.userName}."',
        '"Believe you can\nand you\'re halfway there,\n${widget.userName}."',
        '"Make today so awesome\nyesterday gets jealous,\n${widget.userName}!"',
        '"${widget.userName},\nevery master was\nonce a beginner."'
      ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 8), (timer) {
      if (mounted) {
        setState(() {
          _quoteIndex = (_quoteIndex + 1) % _quotes.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentQuote = _quotes[_quoteIndex].toUpperCase();
    
    // Split text into words, then letters to handle wrapping correctly
    List<Widget> wordWidgets = [];
    final words = currentQuote.split(' ');
    
    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      final isLast = i == words.length - 1;
      
      // Split word into letters
      List<Widget> letterWidgets = [];
      for (int j = 0; j < word.length; j++) {
        final char = word[j];
        if (char == '\n') {
          // Force a new line by returning a container that takes full width
          // However, Wrap doesn't break on full width unless it's a specific width.
          // For simplicity, we just keep the \n logic in text or use a different approach.
          // Since it's easier to just animate whole words or lines:
        }
      }
    }

    // A simpler approach with flutter_animate is to just animate words
    // Or we can animate characters by using a Wrap
    
    // Let's split by characters and preserve spaces
    List<Widget> characters = [];
    for (int i = 0; i < currentQuote.length; i++) {
      final char = currentQuote[i];
      if (char == '\n') {
         characters.add(const SizedBox(width: double.infinity));
      } else {
         characters.add(Text(
           char,
           style: const TextStyle(
             color: Colors.white,
             fontSize: 48,
             fontWeight: FontWeight.w900,
             letterSpacing: 2.0,
             height: 1.2,
             shadows: [
               Shadow(color: Colors.black, offset: Offset(4, 4)),
             ],
           ),
         ));
      }
    }

    return SizedBox(
      width: double.infinity,
      child: Wrap(key: ValueKey(_quoteIndex),
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: characters
            .animate(interval: 40.ms)
            .fadeIn(duration: 300.ms)
            .slideY(begin: 0.2, end: 0, duration: 300.ms, curve: Curves.easeOutCubic)
            .toList(),
      ),
    );
  }
}

