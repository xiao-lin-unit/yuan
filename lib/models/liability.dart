import 'money.dart';

/// 负债类型
enum LiabilityType {
  mortgage('mortgage', '房贷'),
  carLoan('car_loan', '车贷'),
  creditCard('credit_card', '信用卡'),
  consumerLoan('consumer_loan', '消费贷'),
  decorationLoan('decoration_loan', '装修贷'),
  studentLoan('student_loan', '助学贷'),
  onlineLoan('online_loan', '网贷'),
  ecommerceInstallment('ecommerce_installment', '电商分期'),
  rentInstallment('rent_installment', '租金分期'),
  loanFromFriend('loan_from_friend', '亲友借款'),
  other('other', '其他负债');

  final String code;
  final String label;
  const LiabilityType(this.code, this.label);
}

/// 还款方式
enum RepaymentMethod {
  equalInstallment('equal_installment', '等额本息'),
  equalPrincipal('equal_principal', '等额本金'),
  flexible('flexible', '随借随还'),
  interestFirst('interest_first', '先息后本');

  final String code;
  final String label;
  const RepaymentMethod(this.code, this.label);
}

/// 负债
class Liability {
  final String id;
  final String name;
  final LiabilityType type;
  final Money remainingPrincipal;
  final bool isInterestBearing;
  final double annualInterestRate; // 0~1
  final DateTime borrowDate;
  final DateTime? dueDate;
  final RepaymentMethod repaymentMethod;
  final Money periodPayment;
  final int paidPeriods;
  final int? totalPeriods;
  final String? linkedAccountId;
  final String? remark;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool deleted;

  const Liability({
    required this.id,
    required this.name,
    required this.type,
    required this.remainingPrincipal,
    this.isInterestBearing = true,
    this.annualInterestRate = 0,
    required this.borrowDate,
    this.dueDate,
    this.repaymentMethod = RepaymentMethod.flexible,
    this.periodPayment = Money.zero,
    this.paidPeriods = 0,
    this.totalPeriods,
    this.linkedAccountId,
    this.remark,
    required this.createdAt,
    required this.updatedAt,
    this.deleted = false,
  });
}

/// 单期还款计划
class RepaymentSchedule {
  final String id;
  final String liabilityId;
  final int periodNumber;
  final DateTime dueDate;
  final Money principal;
  final Money interest;
  final Money totalPayment;
  final ScheduleStatus status;
  final DateTime? paidAt;

  const RepaymentSchedule({
    required this.id,
    required this.liabilityId,
    required this.periodNumber,
    required this.dueDate,
    required this.principal,
    required this.interest,
    required this.totalPayment,
    this.status = ScheduleStatus.pending,
    this.paidAt,
  });
}

enum ScheduleStatus { pending, paid, overdue }

/// 根据还款方式自动生成还款计划
List<RepaymentSchedule> generateSchedule(Liability l) {
  if (l.totalPeriods == null || l.totalPeriods! <= 0) return [];

  final List<RepaymentSchedule> list = [];
  final monthlyRate = l.annualInterestRate / 12;
  Money remaining = l.remainingPrincipal;

  for (int i = 1; i <= l.totalPeriods!; i++) {
    final due = DateTime(l.borrowDate.year, l.borrowDate.month + i, l.borrowDate.day);
    Money principal = Money.zero;
    Money interest = Money.zero;
    Money total = Money.zero;

    switch (l.repaymentMethod) {
      case RepaymentMethod.equalInstallment:
        // 等额本息
        if (monthlyRate == 0) {
          total = Money.fromCents(l.remainingPrincipal.cents ~/ l.totalPeriods!);
          principal = total;
        } else {
          final factor = (1 - (1 + monthlyRate).pow(l.totalPeriods! - i + 1));
          total = Money.fromCents(
              (l.periodPayment.cents * (1 - (1 + monthlyRate).pow(-l.totalPeriods!))).round());
          interest = Money.fromCents((remaining.cents * monthlyRate).round());
          principal = total - interest;
        }
        break;
      case RepaymentMethod.equalPrincipal:
        // 等额本金
        principal = Money.fromCents(l.remainingPrincipal.cents ~/ l.totalPeriods!);
        interest = Money.fromCents((remaining.cents * monthlyRate).round());
        total = principal + interest;
        break;
      case RepaymentMethod.flexible:
        total = l.periodPayment;
        principal = total;
        break;
      case RepaymentMethod.interestFirst:
        // 先息后本：前期只还息，末期还本金
        if (i < l.totalPeriods!) {
          interest = Money.fromCents((remaining.cents * monthlyRate).round());
          total = interest;
        } else {
          interest = Money.fromCents((remaining.cents * monthlyRate).round());
          principal = remaining;
          total = principal + interest;
        }
        break;
    }

    list.add(RepaymentSchedule(
      id: '${l.id}_p$i',
      liabilityId: l.id,
      periodNumber: i,
      dueDate: due,
      principal: principal,
      interest: interest,
      totalPayment: total,
      status: i <= l.paidPeriods ? ScheduleStatus.paid : ScheduleStatus.pending,
    ));

    remaining = remaining - principal;
  }
  return list;
}
