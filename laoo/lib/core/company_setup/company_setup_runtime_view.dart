import 'package:flutter/material.dart';

import 'company_date_formatter.dart';
import 'company_setup_controller.dart';

class CompanySetupRuntimeView extends StatelessWidget {
  const CompanySetupRuntimeView({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: companySetupController,
      builder: (context, child) {
        final setup = companySetupController.current;
        if (setup == null) {
          return const SizedBox.shrink();
        }

        final dateText =
            CompanyDateFormatter.formatCurrentDate(setup);

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              size: 15,
              color: Color(0xFF6B746E),
            ),
            const SizedBox(width: 6),
            Text(
              dateText,
              style: const TextStyle(
                fontSize: 11.5,
                color: Color(0xFF6B746E),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      },
    );
  }
}

class CompanySetupVersionText extends StatelessWidget {
  const CompanySetupVersionText({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: companySetupController,
      builder: (context, child) {
        final text = companySetupController.versionText;
        if (text.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFFA8B4AE),
              fontSize: 9.2,
              height: 1,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      },
    );
  }
}
