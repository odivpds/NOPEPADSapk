import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:nopepads_mobile/widgets/note_toolbar.dart';

void main() {
  group('NoteToolbarActions Tests', () {
    late quill.QuillController controller;

    setUp(() {
      controller = quill.QuillController.basic();
    });

    tearDown(() {
      controller.dispose();
    });

    test('Toggling Bold attribute', () {
      expect(NoteToolbarActions.isAttributeSet(controller, quill.Attribute.bold), isFalse);

      NoteToolbarActions.toggleAttribute(controller, quill.Attribute.bold);
      expect(NoteToolbarActions.isAttributeSet(controller, quill.Attribute.bold), isTrue);

      NoteToolbarActions.toggleAttribute(controller, quill.Attribute.bold);
      expect(NoteToolbarActions.isAttributeSet(controller, quill.Attribute.bold), isFalse);
    });

    test('Toggling Italic attribute', () {
      expect(NoteToolbarActions.isAttributeSet(controller, quill.Attribute.italic), isFalse);

      NoteToolbarActions.toggleAttribute(controller, quill.Attribute.italic);
      expect(NoteToolbarActions.isAttributeSet(controller, quill.Attribute.italic), isTrue);

      NoteToolbarActions.toggleAttribute(controller, quill.Attribute.italic);
      expect(NoteToolbarActions.isAttributeSet(controller, quill.Attribute.italic), isFalse);
    });

    test('Toggling Highlight attribute', () {
      expect(NoteToolbarActions.isHighlight(controller), isFalse);

      NoteToolbarActions.toggleHighlight(controller);
      expect(NoteToolbarActions.isHighlight(controller), isTrue);

      NoteToolbarActions.toggleHighlight(controller);
      expect(NoteToolbarActions.isHighlight(controller), isFalse);
    });

    test('Toggling Checklist attribute', () {
      expect(NoteToolbarActions.isCheck(controller), isFalse);

      NoteToolbarActions.toggleCheck(controller);
      expect(NoteToolbarActions.isCheck(controller), isTrue);

      NoteToolbarActions.toggleCheck(controller);
      expect(NoteToolbarActions.isCheck(controller), isFalse);
    });

    test('Undo and Redo actions do not throw', () {
      expect(() => NoteToolbarActions.undo(controller), returnsNormally);
      expect(() => NoteToolbarActions.redo(controller), returnsNormally);
    });

    test('Clear formatting action works safely', () {
      NoteToolbarActions.toggleAttribute(controller, quill.Attribute.bold);
      NoteToolbarActions.toggleAttribute(controller, quill.Attribute.italic);

      expect(() => NoteToolbarActions.clearFormatting(controller), returnsNormally);
    });
  });
}
