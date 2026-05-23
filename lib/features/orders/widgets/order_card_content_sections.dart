part of 'order_card.dart';

class _OrderCardHeaderRow extends StatelessWidget {
  final OrderItem order;
  final int number;

  const _OrderCardHeaderRow({required this.order, required this.number});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Row(
            children: [
              _NumberBadge(order: order, number: number),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  order.displayId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.blue,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              if (order.isClosed) ...[
                const SizedBox(width: 8),
                Flexible(child: _OrderStatusBadge(order: order)),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 104),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${order.price.toInt()} ₽',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textPrimary(context),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              _PaymentBadge(type: order.payment),
            ],
          ),
        ),
      ],
    );
  }
}

class _OrderStatusBadge extends StatelessWidget {
  final OrderItem order;

  const _OrderStatusBadge({required this.order});

  @override
  Widget build(BuildContext context) {
    final color = order.isFailed ? Colors.red.shade400 : AppColors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        order.isFailed ? 'Не доставлен' : 'Выполнен',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

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

class _OrderCardClientRow extends StatelessWidget {
  final OrderItem order;

  const _OrderCardClientRow({required this.order});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            order.clientName,
            maxLines: 1,
            style: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 92),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.isDark(context)
                  ? AppColors.softSurface(context)
                  : const Color(0xFFD6E8F8),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              order.district,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.isDark(context)
                    ? AppColors.grayBlueLight
                    : AppColors.blue,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OrderCardCommentRow extends StatelessWidget {
  final OrderItem order;

  const _OrderCardCommentRow({required this.order});

  @override
  Widget build(BuildContext context) {
    final comment = order.comment;
    if (comment == null || comment.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 13,
            color: AppColors.orange,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              comment,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.orange,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderCardFooterRow extends StatelessWidget {
  final OrderItem order;
  final bool showRouteButton;

  const _OrderCardFooterRow({
    required this.order,
    required this.showRouteButton,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              const Icon(
                Icons.water_drop_outlined,
                size: 15,
                color: AppColors.lightBlue,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  '${order.bottles} бут.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textSecondary(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (!order.isClosed && order.scannedItems.isNotEmpty) ...[
                const SizedBox(width: 8),
                const Icon(
                  Icons.qr_code_scanner_rounded,
                  size: 15,
                  color: AppColors.green,
                ),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    '${order.scannedItems['water'] ?? 0}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (showRouteButton) ...[
          const SizedBox(width: 8),
          _OrderRouteButtonSlot(order: order),
        ],
      ],
    );
  }
}

class _OrderRouteButtonSlot extends StatelessWidget {
  final OrderItem order;

  const _OrderRouteButtonSlot({required this.order});

  @override
  Widget build(BuildContext context) {
    final hasCoordinates = order.hasCoordinates;
    return SizedBox(
      width: _routeActionColumnWidth,
      child: Align(
        alignment: Alignment.centerRight,
        child: GestureDetector(
          onTap: hasCoordinates
              ? () => NavigationService.openExternalRoute(order.lat, order.lng)
              : null,
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 11),
            decoration: BoxDecoration(
              color: hasCoordinates
                  ? null
                  : AppColors.grayBlue.withValues(alpha: 0.42),
              gradient: hasCoordinates
                  ? const LinearGradient(
                      colors: [AppColors.orange, AppColors.orangeLight],
                    )
                  : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    hasCoordinates ? 'Маршрут' : 'Нет гео',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(
                    hasCoordinates
                        ? Icons.arrow_forward_rounded
                        : Icons.location_off_rounded,
                    color: Colors.white,
                    size: 13,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
