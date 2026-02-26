import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';

class FinancePage extends StatelessWidget {
  const FinancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Provider.of<FinanceProvider>(context);

    return Container(
      decoration: AppTheme.pageGradient,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Center(
                child: Text('Money Tracker',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
              ),
              const SizedBox(height: 24),

              // Budget Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: AppTheme.glassCard(opacity: 0.2),
                child: Column(
                  children: [
                    const Text('FREE MONEY',
                        style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2)),
                    const SizedBox(height: 8),
                    Text(
                      '${p.freeMoney.toStringAsFixed(0)} AZN',
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w300,
                        color: p.freeMoney > 500
                            ? AppTheme.success
                            : p.freeMoney > 200
                                ? AppTheme.warning
                                : AppTheme.danger,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: p.spentPercent,
                        backgroundColor: AppTheme.divider,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          p.spentPercent > 0.8
                              ? AppTheme.danger
                              : p.spentPercent > 0.5
                                  ? AppTheme.warning
                                  : AppTheme.primary,
                        ),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Spent: ${p.spent.toStringAsFixed(0)} AZN',
                            style: const TextStyle(
                                color: AppTheme.textSecondary, fontSize: 12)),
                        Text('Budget: ${p.budget.toStringAsFixed(0)} AZN',
                            style: const TextStyle(
                                color: AppTheme.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Category breakdown
              if (p.categoryTotals.isNotEmpty) ...[
                const Text('By Category',
                    style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1)),
                const SizedBox(height: 12),
                _buildCategoryChart(p),
                const SizedBox(height: 20),
              ],

              // Add expense
              _AddExpenseWidget(),
              const SizedBox(height: 20),

              // History
              if (p.expenses.isNotEmpty) ...[
                const Text('Recent',
                    style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1)),
                const SizedBox(height: 8),
                ...p.expenses.take(10).toList().asMap().entries.map((entry) {
                  final idx = entry.key;
                  final e = entry.value;
                  final cat = FinanceProvider.categories.firstWhere(
                    (c) => c['name'] == e['category'],
                    orElse: () => FinanceProvider.categories.last,
                  );
                  return Dismissible(
                    key: ValueKey('expense_${e['time']}_$idx'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                        color: AppTheme.danger.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.centerRight,
                      child: const Icon(Icons.delete_outline,
                          color: AppTheme.danger, size: 20),
                    ),
                    onDismissed: (_) => p.deleteExpense(idx),
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Text(cat['icon'] as String,
                              style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(cat['name'] as String,
                                style: const TextStyle(
                                    color: AppTheme.textPrimary, fontSize: 14)),
                          ),
                          Text(
                              '-${(e['amount'] as double).toStringAsFixed(0)} AZN',
                              style: const TextStyle(
                                  color: AppTheme.danger,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14)),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChart(FinanceProvider p) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: p.categoryTotals.entries.map((e) {
        final cat = FinanceProvider.categories.firstWhere(
          (c) => c['name'] == e.key,
          orElse: () => FinanceProvider.categories.last,
        );
        final pct = p.spent > 0 ? (e.value / p.spent * 100) : 0;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Color(cat['color'] as int).withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: Color(cat['color'] as int).withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(cat['icon'] as String, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text('${e.value.toStringAsFixed(0)} AZN',
                  style: TextStyle(
                      color: Color(cat['color'] as int),
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
              const SizedBox(width: 4),
              Text('${pct.toStringAsFixed(0)}%',
                  style: TextStyle(
                      color: Color(cat['color'] as int).withOpacity(0.6),
                      fontSize: 11)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _AddExpenseWidget extends StatefulWidget {
  @override
  State<_AddExpenseWidget> createState() => _AddExpenseWidgetState();
}

class _AddExpenseWidgetState extends State<_AddExpenseWidget> {
  final TextEditingController _amtCtrl = TextEditingController();
  String _selectedCategory = 'Food';

  @override
  Widget build(BuildContext context) {
    final p = Provider.of<FinanceProvider>(context, listen: false);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassCard(opacity: 0.15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Add Expense',
              style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1)),
          const SizedBox(height: 12),
          // Category chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: FinanceProvider.categories.map((cat) {
              final selected = _selectedCategory == cat['name'];
              return GestureDetector(
                onTap: () =>
                    setState(() => _selectedCategory = cat['name'] as String),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected
                        ? Color(cat['color'] as int).withOpacity(0.25)
                        : AppTheme.surfaceLight.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected
                          ? Color(cat['color'] as int)
                          : AppTheme.divider,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(cat['icon'] as String,
                          style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 4),
                      Text(cat['name'] as String,
                          style: TextStyle(
                              color: selected
                                  ? Color(cat['color'] as int)
                                  : AppTheme.textSecondary,
                              fontSize: 12,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          // Amount input + button
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amtCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Amount (AZN)',
                    prefixIcon: Icon(Icons.attach_money, size: 18),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  final amt = double.tryParse(_amtCtrl.text) ?? 0;
                  if (amt > 0) {
                    p.add(amt, category: _selectedCategory);
                    _amtCtrl.clear();
                  }
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [AppTheme.primary, AppTheme.accent]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
