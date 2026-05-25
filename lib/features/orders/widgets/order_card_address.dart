part of 'order_card.dart';

class _OrderCardAddressRow extends StatelessWidget {
  final OrderItem order;

  const _OrderCardAddressRow({required this.order});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.location_on_outlined,
          size: 14,
          color: AppColors.grayBlueLight,
        ),
        const SizedBox(width: 4),
        Expanded(child: _AdaptiveOrderAddressText(address: order.address)),
      ],
    );
  }
}

class _AdaptiveOrderAddressText extends StatelessWidget {
  final String address;

  const _AdaptiveOrderAddressText({required this.address});

  static const _maxFontSize = 15.0;
  static const _minFontSize = 11.5;
  static const _fontStep = 0.5;
  static const _maxLines = 2;

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(
      color: AppColors.textPrimary(context),
      fontSize: _maxFontSize,
      fontWeight: FontWeight.w700,
      height: 1.15,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final textDirection = Directionality.of(context);
        var fontSize = _maxFontSize;

        while (fontSize > _minFontSize &&
            _overflows(
              address,
              baseStyle.copyWith(fontSize: fontSize),
              constraints.maxWidth,
              textDirection,
            )) {
          fontSize -= _fontStep;
        }

        return Text(
          address,
          maxLines: _maxLines,
          overflow: TextOverflow.ellipsis,
          style: baseStyle.copyWith(fontSize: fontSize),
        );
      },
    );
  }

  bool _overflows(
    String text,
    TextStyle style,
    double maxWidth,
    TextDirection textDirection,
  ) {
    final painter = TextPainter(
      maxLines: _maxLines,
      text: TextSpan(text: text, style: style),
      textDirection: textDirection,
    )..layout(maxWidth: maxWidth);

    return painter.didExceedMaxLines;
  }
}
