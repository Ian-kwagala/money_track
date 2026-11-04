import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/category.dart';
import '../../models/frequency.dart';
import '../../models/transaction.dart';
import '../../viewmodels/tracker_view_model.dart';
import '../home_shell.dart';
import '../format/money_format.dart';
import '../theme/app_theme.dart';

/// Lists every category in three groups (recurring expenses, one-time
/// expenses, income) with this month's spending, and lets the user create,
/// edit or delete them in a bottom sheet.
///
/// Icons: this screen offers its own icon keys ('ShoppingBag', 'Bus'...).
/// [Category.materialIcon] knows those as well as the seeded keys
/// ('restaurant', 'directions_bus'...) and Quick add's, so every category
/// shows its icon on every screen.
class CategoryManagerScreen extends StatefulWidget {
  const CategoryManagerScreen({super.key});

  @override
  State<CategoryManagerScreen> createState() => _CategoryManagerScreenState();
}

class _CategoryManagerScreenState extends State<CategoryManagerScreen> {
  // State of the create/edit sheet, which is shown as the Scaffold's
  // persistent bottomSheet while [_showSheet] is true.
  final _nameCtrl = TextEditingController();
  String _selectedIcon = 'ShoppingBag';
  bool _showSheet = false;

  /// The category being edited, or null when creating a new one.
  Category? _editingCategory;

  // 0 = Expense recurring, 1 = Expense one-time, 2 = Income
  int _typeIndex = 0;

  /// [_typeIndex] when the edit sheet opened. Left unchanged, the category
  /// keeps its own frequency (e.g. weekly, set from Quick add).
  int? _openedTypeIndex;

  /// Icon keys offered in the picker grid (named after the original web
  /// design's icon set).
  static const _iconNames = [
    'ShoppingBag', 'Bus', 'Home', 'Zap', 'Droplets', 'Fuel',
    'Spray', 'Heart', 'Music', 'Coffee', 'Smartphone', 'GraduationCap',
    'Shield', 'Laptop', 'MapPin', 'Plane', 'PiggyBank', 'AttachMoney',
    'Briefcase', 'PawPrint', 'Gamepad2', 'Film', 'PartyPopper', 'Package2',
    'Utensils', 'Tram', 'Building', 'Wind', 'Waves', 'Leaf',
    'Stethoscope', 'Headphones', 'Cake', 'Phone', 'BookOpen', 'BadgeCheck',
    'Building2', 'Map', 'Rocket', 'Target', 'Gem', 'BriefcaseMedical',
    'Bone', 'Controller', 'Clapperboard', 'Gift', 'Box',
  ];

  // Both this screen's icon keys and the app's resolve here.
  IconData _iconForName(String name) => Category.materialIcon(name);

  /// Opens the sheet empty, ready for a new monthly expense category.
  void _openCreateSheet() {
    _editingCategory = null;
    _nameCtrl.clear();
    _selectedIcon = 'ShoppingBag';
    _typeIndex = 0;
    _openedTypeIndex = null;
    setState(() => _showSheet = true);
  }

  /// Opens the sheet filled in from [cat], with the type tab worked out from
  /// its [Category.type] and [Category.frequency].
  void _openEditSheet(Category cat) {
    _editingCategory = cat;
    _nameCtrl.text = cat.name;
    _selectedIcon = cat.icon.isNotEmpty ? cat.icon : 'ShoppingBag';
    if (cat.type == TxType.income) {
      _typeIndex = 2;
    } else if (cat.frequency == 'once') {
      _typeIndex = 1;
    } else {
      _typeIndex = 0;
    }
    _openedTypeIndex = _typeIndex;
    setState(() => _showSheet = true);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TrackerViewModel>();
    final symbol = vm.settings.currencySymbol;
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    final expenseRecurring = vm.expenseCategories.where((c) => c.frequency != 'once').toList();
    final expenseOnce = vm.expenseCategories.where((c) => c.frequency == 'once').toList();
    final income = vm.incomeCategories;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          top: false,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: PageHeader(title: 'Categories', subtitle: '${expenseRecurring.length + expenseOnce.length + income.length} total'),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Expense Monthly section
                      if (expenseRecurring.isNotEmpty) ...[
                        _sectionHeader('Expense \u2014 Recurring', Icons.repeat, AppColors.danger),
                        const SizedBox(height: 8),
                        _buildGrid(vm, expenseRecurring, monthStart, now, symbol),
                        const SizedBox(height: 20),
                      ],

                      // Expense One-time section
                      if (expenseOnce.isNotEmpty) ...[
                        _sectionHeader('Expense \u2014 One-time', Icons.flash_on, AppColors.warning),
                        const SizedBox(height: 8),
                        _buildGrid(vm, expenseOnce, monthStart, now, symbol),
                        const SizedBox(height: 20),
                      ],

                      // Income section
                      if (income.isNotEmpty) ...[
                        _sectionHeader('Income', Icons.trending_up, AppColors.badgeMintText),
                        const SizedBox(height: 8),
                        _buildGrid(vm, income, monthStart, now, symbol),
                        const SizedBox(height: 20),
                      ],

                      // Add category button
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _openCreateSheet,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Category'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusPill)),
                            side: const BorderSide(color: AppColors.borderLight),
                            foregroundColor: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomSheet: _showSheet ? _buildSheet(context, vm) : null,
    );
  }

  Widget _sectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }

  /// Three-column grid of category cards, each showing this month's spend.
  Widget _buildGrid(TrackerViewModel vm, List<Category> cats, DateTime monthStart, DateTime now, String symbol) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 0.85,
      children: [
        for (final c in cats)
          _CategoryCard(
            category: c,
            spent: vm.spentByCategory(monthStart, now, c.id),
            symbol: symbol,
            onTap: () => _openEditSheet(c),
          ),
      ],
    );
  }

  /// The create/edit form: type, name, icon picker, save (and delete when
  /// editing).
  Widget _buildSheet(BuildContext context, TrackerViewModel vm) {
    final isEditing = _editingCategory != null;
    return Container(
      decoration: AppColors.cardDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(isEditing ? 'Edit category' : 'New category', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const Spacer(),
                if (isEditing)
                  InkWell(
                    onTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete category?'),
                          content: Text('Delete "${_editingCategory!.name}"? This cannot be undone.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                            FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: AppColors.danger), child: const Text('Delete')),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await vm.deleteCategory(_editingCategory!.id);
                        _editingCategory = null;
                        _nameCtrl.clear();
                        setState(() => _showSheet = false);
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Category deleted')));
                      }
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.delete_outline, size: 20, color: AppColors.danger),
                    ),
                  ),
                InkWell(
                  onTap: () => setState(() { _showSheet = false; _editingCategory = null; }),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(padding: const EdgeInsets.all(6), child: const Icon(Icons.close, size: 20, color: AppColors.mutedForeground)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Type selector
            const Text('Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.mutedForeground)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF141E30),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderLight, width: 1),
              ),
              child: Row(
                children: [
                  _typeChip(0, _recurringLabel, Icons.repeat, AppColors.danger),
                  _typeChip(1, 'One-time', Icons.flash_on, AppColors.warning),
                  _typeChip(2, 'Income', Icons.trending_up, AppColors.badgeMintText),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Name
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: 'Category name',
                hintText: 'e.g. Salon',
                hintStyle: const TextStyle(color: AppColors.mutedForeground),
                filled: true,
                fillColor: const Color(0xFF141E30),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.borderLight, width: 1)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.borderLight, width: 1)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // Icon picker
            const Text('Pick an icon', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.mutedForeground)),
            const SizedBox(height: 8),
            SizedBox(
              height: 160,
              child: GridView.count(
                crossAxisCount: 6,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1,
                children: [
                  for (final i in _iconNames)
                    InkWell(
                      onTap: () => setState(() => _selectedIcon = i),
                      borderRadius: BorderRadius.circular(AppColors.radiusMd),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _selectedIcon == i ? AppColors.primary : Colors.white.withOpacity(0.08),
                            width: _selectedIcon == i ? 1.5 : 1,
                          ),
                          borderRadius: BorderRadius.circular(AppColors.radiusMd),
                          color: _selectedIcon == i ? AppColors.primary.withValues(alpha: 0.15) : const Color(0xFF141E30),
                        ),
                        child: Center(child: Icon(_iconForName(i), size: 22, color: _selectedIcon == i ? AppColors.primary : AppColors.mutedForeground)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Save button
            SizedBox(
              width: double.infinity,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF18263E), Color(0xFF0F172A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppColors.radiusPill),
                  border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
                  boxShadow: const [
                    BoxShadow(color: Color(0x1A000000), blurRadius: 10, offset: Offset(0, 4)),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppColors.radiusPill),
                    onTap: _nameCtrl.text.trim().isEmpty
                        ? null
                        : () async {
                            final TxType txType = _typeIndex == 2 ? TxType.income : TxType.expense;
                            final editing = _editingCategory;
                            final String freq = editing != null && _typeIndex == _openedTypeIndex
                                ? editing.frequency
                                : _typeIndex == 1 ? 'once' : 'monthly';

                            if (isEditing) {
                              final updated = Category(
                                id: _editingCategory!.id,
                                name: _nameCtrl.text.trim(),
                                icon: _selectedIcon,
                                color: _editingCategory!.color,
                                type: txType,
                                frequency: freq,
                                isBuiltIn: _editingCategory!.isBuiltIn,
                              );
                              await vm.updateCategory(updated);
                            } else {
                              final cat = Category(
                                id: 'cat_${DateTime.now().millisecondsSinceEpoch}',
                                name: _nameCtrl.text.trim(),
                                icon: _selectedIcon,
                                color: _typeIndex == 2 ? AppColors.success.toARGB32() : AppColors.primary.toARGB32(),
                                type: txType,
                                frequency: freq,
                              );
                              await vm.addCategory(cat);
                            }
                            _nameCtrl.clear();
                            _editingCategory = null;
                            setState(() => _showSheet = false);
                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEditing ? 'Category updated' : 'Category created')));
                          },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(isEditing ? Icons.check : Icons.add, size: 18, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(
                            isEditing ? 'Update category' : 'Create category',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "Monthly", or the category's own frequency when it has another one.
  String get _recurringLabel {
    final cat = _editingCategory;
    if (cat == null || cat.type == TxType.income || cat.frequency == 'once') return 'Monthly';
    return cat.usualFrequency.label;
  }

  /// One segment of the Monthly / One-time / Income selector.
  Widget _typeChip(int index, String label, IconData icon, Color color) {
    final selected = _typeIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _typeIndex = index),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: selected ? AppColors.cardGradient : null,
            borderRadius: BorderRadius.circular(10),
            border: selected ? Border.all(color: Colors.white.withOpacity(0.12), width: 1) : null,
            boxShadow: selected ? const [BoxShadow(color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, 2))] : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: selected ? color : AppColors.mutedForeground),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: selected ? color : AppColors.mutedForeground)),
            ],
          ),
        ),
      ),
    );
  }
}

/// One category tile: icon, name, type and this month's spend ("—" for
/// none). Tapping opens it for editing.
class _CategoryCard extends StatelessWidget {
  final Category category;
  final double spent;
  final String symbol;
  final VoidCallback? onTap;

  const _CategoryCard({required this.category, required this.spent, required this.symbol, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = Color(category.color);
    final displayAmount = spent > 0 ? spent : 0.0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppColors.radiusXl),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusXl),
          side: const BorderSide(color: AppColors.borderLight, width: 1),
        ),
        child: Container(
          decoration: AppColors.cardDecoration(),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppColors.radius2xl),
                  border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
                ),
                child: Center(child: Icon(_iconForName(category.icon), size: 28, color: color)),
              ),
              const SizedBox(height: 8),
              Text(category.name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(
                category.type == TxType.income
                    ? 'Income'
                    : category.frequency == 'once' ? 'One-time' : category.usualFrequency.label,
                style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w500, color: AppColors.mutedForeground),
              ),
              const SizedBox(height: 2),
              Text(displayAmount > 0 ? MoneyFormat.compact(displayAmount, symbol: symbol) : '\u2014', style: const TextStyle(fontSize: 9, color: AppColors.mutedForeground)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Icon for a category's stored key (this screen's keys or the app's).
/// Used by [_CategoryCard].
IconData _iconForName(String name) => Category.materialIcon(name);
