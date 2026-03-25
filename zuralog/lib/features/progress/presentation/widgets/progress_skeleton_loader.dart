library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/shared/widgets/loading/z_loading_skeleton.dart';

class ProgressSkeletonLoader extends StatelessWidget {
  const ProgressSkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        AppDimens.bottomClearance(context),
      ),
      children: [
        const ZLoadingSkeleton(
          width: double.infinity,
          height: 160,
          borderRadius: AppDimens.radiusCard,
        ),
        const SizedBox(height: AppDimens.spaceLg),
        Row(children: [
          const Expanded(child: ZLoadingSkeleton(width: double.infinity, height: 72, borderRadius: AppDimens.radiusCard)),
          const SizedBox(width: AppDimens.spaceSm),
          const Expanded(child: ZLoadingSkeleton(width: double.infinity, height: 72, borderRadius: AppDimens.radiusCard)),
          const SizedBox(width: AppDimens.spaceSm),
          const Expanded(child: ZLoadingSkeleton(width: double.infinity, height: 72, borderRadius: AppDimens.radiusCard)),
          const SizedBox(width: AppDimens.spaceSm),
          const Expanded(child: ZLoadingSkeleton(width: double.infinity, height: 72, borderRadius: AppDimens.radiusCard)),
        ]),
        const SizedBox(height: AppDimens.spaceLg),
        const ZLoadingSkeleton(
          width: double.infinity,
          height: 88,
          borderRadius: AppDimens.radiusCard,
        ),
        const SizedBox(height: AppDimens.spaceLg),
        const ZLoadingSkeleton(
          width: double.infinity,
          height: 100,
          borderRadius: AppDimens.radiusCard,
        ),
        const SizedBox(height: AppDimens.spaceLg),
        const ZLoadingSkeleton(width: 120, height: 20),
        const SizedBox(height: AppDimens.spaceSm),
        const ZLoadingSkeleton(
          width: double.infinity,
          height: 96,
          borderRadius: AppDimens.radiusCard,
        ),
        const SizedBox(height: AppDimens.spaceSm),
        const ZLoadingSkeleton(
          width: double.infinity,
          height: 96,
          borderRadius: AppDimens.radiusCard,
        ),
        const SizedBox(height: AppDimens.spaceLg),
        const ZLoadingSkeleton(
          width: double.infinity,
          height: 72,
          borderRadius: AppDimens.radiusCard,
        ),
      ],
    );
  }
}
