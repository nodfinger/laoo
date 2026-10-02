import 'package:laoo_shared_core/laoo_shared_core.dart';

abstract final class KnowledgeProject {
  static const code = 'LAOO_KNOWLEDGE';
}

abstract final class KnowledgeMenuCodes {
  static const settings = '49001';
  static const taxonomy = '49002';
  static const articles = '49003';
  static const reviews = '49004';
  static const library = '49005';
  static const questions = '49006';
  static const mine = '49007';
  static const reports = '49008';
}

abstract final class KnowledgeRoutes {
  static const all = <FeatureRouteContract>[
    FeatureRouteContract(
      projectCode: KnowledgeProject.code,
      menuCode: '49001',
      screenType: 2,
      routeName: 'knowledgeSettings',
      routePath: '/company/knowledge-settings',
      isImplemented: true,
    ),
    FeatureRouteContract(
      projectCode: KnowledgeProject.code,
      menuCode: '49002',
      screenType: 1,
      routeName: 'knowledgeTaxonomy',
      routePath: '/company/knowledge-taxonomy',
      isImplemented: true,
    ),
    FeatureRouteContract(
      projectCode: KnowledgeProject.code,
      menuCode: '49003',
      screenType: 4,
      routeName: 'knowledgeArticles',
      routePath: '/company/knowledge-articles',
      isImplemented: true,
    ),
    FeatureRouteContract(
      projectCode: KnowledgeProject.code,
      menuCode: '49004',
      screenType: 2,
      routeName: 'knowledgeReviews',
      routePath: '/company/knowledge-reviews',
      isImplemented: true,
    ),
    FeatureRouteContract(
      projectCode: KnowledgeProject.code,
      menuCode: '49005',
      screenType: 3,
      routeName: 'knowledgeLibrary',
      routePath: '/company/knowledge-library',
      isImplemented: true,
    ),
    FeatureRouteContract(
      projectCode: KnowledgeProject.code,
      menuCode: '49006',
      screenType: 1,
      routeName: 'knowledgeQuestions',
      routePath: '/company/knowledge-questions',
      isImplemented: true,
    ),
    FeatureRouteContract(
      projectCode: KnowledgeProject.code,
      menuCode: '49007',
      screenType: 3,
      routeName: 'myKnowledge',
      routePath: '/company/my-knowledge',
      isImplemented: true,
    ),
    FeatureRouteContract(
      projectCode: KnowledgeProject.code,
      menuCode: '49008',
      screenType: 3,
      routeName: 'knowledgeReports',
      routePath: '/company/knowledge-reports',
      isImplemented: true,
    ),
  ];
}
