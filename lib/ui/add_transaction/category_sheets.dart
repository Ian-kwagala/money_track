import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/category.dart';
import '../../models/frequency.dart';
import '../../models/transaction.dart';
import '../../viewmodels/tracker_view_model.dart';
import '../theme/app_theme.dart';
import '../widgets/action_button.dart';

/// A round category icon with its name underneath, as used in Quick add's
/// grid. Also draws the grid's "More" and "New" tiles.
class CategoryTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Plain (not tinted) circle, for the "More" and "New" tiles.
  final bool action;

  const CategoryTile({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.action = false,
  });

  CategoryTile.of(Category cat, {Key? key, required bool selected, required VoidCallback onTap})
      : this(key: key, icon: cat.iconData, color: Color(cat.color), label: cat.name, selected: selected, onTap: onTap);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 2),
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: action ? AppColors.bg : color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: selected
                      ? Border.all(color: AppColors.primary, width: 2)
                      : action
                          ? Border.all(color: AppColors.primary.withValues(alpha: 0.35))
                          : null,
                ),
                child: Icon(icon, color: action ? AppColors.primary : color, size: action ? 20 : 18),
              ),
              const SizedBox(height: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: selected || action ? FontWeight.w700 : FontWeight.w500,
                    color: action ? AppColors.primary : AppColors.textPrimary,
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

/// Every category of one type, for when the one you want isn't in Quick
/// add's grid. Returns the picked category's id, or [newCategory].
class CategoryPickerSheet extends StatelessWidget {
  static const newCategory = '__new__';

  final List<Category> categories;
  final String? selectedId;
  final TxType type;

  const CategoryPickerSheet({super.key, required this.categories, required this.type, this.selectedId});

  static Future<String?> show(BuildContext context,
          {required List<Category> categories, required TxType type, String? selectedId}) =>
      showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => CategoryPickerSheet(categories: categories, type: type, selectedId: selectedId),
      );

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * 0.8;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _Handle(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        type == TxType.income ? 'All income categories' : 'All expense categories',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 20, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: GridView.count(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  crossAxisCount: 4,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.95,
                  children: [
                    for (final c in categories)
                      CategoryTile.of(c, selected: c.id == selectedId, onTap: () => Navigator.pop(context, c.id)),
                    CategoryTile(
                      icon: Icons.add_rounded,
                      color: AppColors.primary,
                      label: 'New',
                      action: true,
                      onTap: () => Navigator.pop(context, newCategory),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What [NewCategorySheet] hands back.
class NewCategoryResult {
  final Category category;

  /// True when a category with that name was already there; it's returned
  /// instead of making a second one.
  final bool existed;

  const NewCategoryResult(this.category, {this.existed = false});
}

/// "New category": what the money was for, how often it happens, an icon
/// and a colour. The frequency is remembered, so Quick add picks it again
/// whenever this category is chosen.
class NewCategorySheet extends StatefulWidget {
  final TxType type;
  final Frequency initialFrequency;

  const NewCategorySheet({super.key, required this.type, this.initialFrequency = Frequency.once});

  static Future<NewCategoryResult?> show(BuildContext context,
          {required TxType type, Frequency initialFrequency = Frequency.once}) =>
      showModalBottomSheet<NewCategoryResult>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => NewCategorySheet(type: type, initialFrequency: initialFrequency),
      );

  static const frequencies = [
    Frequency.once,
    Frequency.daily,
    Frequency.weekly,
    Frequency.biweekly,
    Frequency.monthly,
    Frequency.quarterly,
    Frequency.yearly,
    Frequency.random,
  ];

  static const colors = <int>[
    0xFFEA580C, // orange
    0xFF3B82F6, // blue
    0xFF8B5CF6, // purple
    0xFFEC4899, // pink
    0xFF16A34A, // green
    0xFF14B8A6, // teal
    0xFFEAB308, // yellow
    0xFFDC2626, // red
  ];

  @override
  State<NewCategorySheet> createState() => _NewCategorySheetState();
}

class _NewCategorySheetState extends State<NewCategorySheet> {
  final _name = TextEditingController();
  final _focus = FocusNode();
  late Frequency _frequency;
  late String _icon;
  late int _color;

  /// Once someone taps an icon, typing no longer changes it.
  bool _iconChosen = false;
  String? _error;
  NewCategoryResult? _result;

  bool get _income => widget.type == TxType.income;
  String get _defaultIcon => _income ? 'payments' : 'shopping_cart';

  @override
  void initState() {
    super.initState();
    _frequency =
        NewCategorySheet.frequencies.contains(widget.initialFrequency) ? widget.initialFrequency : Frequency.once;
    _icon = _defaultIcon;
    final own = context.read<TrackerViewModel>().categoriesOf(widget.type).where((c) => !c.isBuiltIn).length;
    _color = NewCategorySheet.colors[own % NewCategorySheet.colors.length];
  }

  @override
  void dispose() {
    _name.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onNameChanged(String value) {
    setState(() {
      _error = null;
      if (!_iconChosen) _icon = Category.suggestIcon(value) ?? _defaultIcon;
    });
  }

  Future<bool> _create() async {
    final name = _name.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (name.isEmpty) {
      setState(() => _error = 'Give it a name, e.g. Salon');
      _focus.requestFocus();
      return false;
    }
    final vm = context.read<TrackerViewModel>();
    final same = vm.categoriesOf(widget.type).where((c) => c.name.toLowerCase() == name.toLowerCase());
    if (same.isNotEmpty) {
      setState(() => _result = NewCategoryResult(same.first, existed: true));
      return true;
    }
    final category = Category(
      id: 'cat_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      icon: _icon,
      color: _color,
      type: widget.type,
      frequency: _frequency.name,
    );
    await vm.addCategory(category);
    if (mounted) setState(() => _result = NewCategoryResult(category));
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final color = Color(_color);
    final ready = _name.text.trim().isNotEmpty;

    Widget label(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(text,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
        );

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: media.size.height * 0.9),
          child: Material(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _Handle(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
                  child: Row(
                    children: [
                      // Live preview of the new category.
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                          child: Icon(Category.materialIcon(_icon), key: ValueKey(_icon), color: color, size: 22),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _income ? 'New income category' : 'New expense category',
                              style: const TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                            ),
                            Text(
                              _income ? 'Where the money comes from' : 'What the money was spent on',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, size: 20, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _name,
                          focusNode: _focus,
                          autofocus: true,
                          textCapitalization: TextCapitalization.sentences,
                          inputFormatters: [LengthLimitingTextInputFormatter(30)],
                          onChanged: _onNameChanged,
                          decoration: InputDecoration(
                            labelText: 'Name',
                            hintText: _income ? 'e.g. Rent income, Tips' : 'e.g. Salon, Boda boda, Church offering',
                            errorText: _error,
                            filled: true,
                            fillColor: AppColors.bg,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 18),
                        label('How often does it happen?'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final f in NewCategorySheet.frequencies)
                              _FrequencyPill(
                                frequency: f,
                                selected: f == _frequency,
                                onTap: () => setState(() => _frequency = f),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _frequency == Frequency.once
                              ? 'A one-off, like a wedding gift.'
                              : 'Quick add will pick ${_frequency.label} for you each time you choose it.',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 18),
                        label('Icon'),
                        SizedBox(
                          height: 100,
                          child: GridView.count(
                            scrollDirection: Axis.horizontal,
                            crossAxisCount: 2,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            children: [
                              for (final name in Category.pickerIcons)
                                _IconChoice(
                                  icon: Category.materialIcon(name),
                                  color: color,
                                  selected: name == _icon,
                                  onTap: () => setState(() {
                                    _icon = name;
                                    _iconChosen = true;
                                  }),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        label('Colour'),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final c in NewCategorySheet.colors)
                              _ColorChoice(
                                color: Color(c),
                                selected: c == _color,
                                onTap: () => setState(() => _color = c),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: ActionButton(
                      label: 'Create category',
                      doneLabel: _result?.existed == true ? 'Already there' : 'Added',
                      icon: Icons.add_rounded,
                      dimmed: !ready,
                      doneFor: const Duration(milliseconds: 450),
                      onPressed: _create,
                      onDone: () => Navigator.pop(context, _result),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 10),
        width: 36,
        height: 4,
        decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
      );
}

class _FrequencyPill extends StatelessWidget {
  final Frequency frequency;
  final bool selected;
  final VoidCallback onTap;

  const _FrequencyPill({required this.frequency, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.primary.withValues(alpha: 0.12) : AppColors.bg,
        shape: StadiumBorder(
            side: BorderSide(color: selected ? AppColors.primary : Colors.transparent, width: 1.2)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(
              frequency.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IconChoice extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _IconChoice({required this.icon, required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? color.withValues(alpha: 0.15) : AppColors.bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: selected ? color : Colors.transparent, width: 1.6),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Icon(icon, size: 20, color: selected ? color : AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _ColorChoice extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ColorChoice({required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: selected ? Border.all(color: AppColors.textPrimary, width: 2.5) : null,
            boxShadow: selected ? [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 8)] : null,
          ),
          child: selected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
        ),
      ),
    );
  }
}
