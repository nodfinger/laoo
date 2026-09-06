import 'package:flutter/material.dart';

import 'company_date_formatter.dart';
import 'company_setup_controller.dart';

class CompanySetupBrandInfo extends StatelessWidget {
  const CompanySetupBrandInfo({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: companySetupController,
      builder: (context, child) {
        final setup = companySetupController.current;
        if (setup == null) {
          return const SizedBox.shrink();
        }

        final version = setup.versionId.trim();
        final date = CompanyDateFormatter.formatCurrentDate(setup);

        return Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (version.isNotEmpty)
                Text(
                  'Version $version',
                  style: const TextStyle(
                    color: Color(0xFFA8B4AE),
                    fontSize: 8.5,
                    height: 1.15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              const SizedBox(height: 3),
              Text(
                date,
                style: const TextStyle(
                  color: Color(0xFFA8B4AE),
                  fontSize: 8.5,
                  height: 1.15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
