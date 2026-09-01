import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_service/core/navigation/navigation_menu.dart';
import 'package:laoo_service/core/navigation/navigation_route_authorization.dart';

void main() {
  NavigationMenuGroup menus(String menuCode) => NavigationMenuGroup(
    code: 'group',
    name: 'Group',
    items: [NavigationMenuItem(code: menuCode, name: 'Menu')],
  );

  test('reuses permission cache only within the same session', () async {
    var calls = 0;
    final authorization = NavigationRouteAuthorization(
      loadMenus: ({bool refresh = false}) async {
        calls++;
        return [menus(calls == 1 ? '01001' : '01002')];
      },
    );

    expect(await authorization.allowedMenuCodes(sessionKey: 'session-a'), {
      '01001',
    });
    expect(await authorization.allowedMenuCodes(sessionKey: 'session-a'), {
      '01001',
    });
    expect(calls, 1);

    expect(await authorization.allowedMenuCodes(sessionKey: 'session-b'), {
      '01002',
    });
    expect(calls, 2);
  });

  test('refresh and logout clearing force a new Navigation API load', () async {
    var calls = 0;
    final authorization = NavigationRouteAuthorization(
      loadMenus: ({bool refresh = false}) async {
        calls++;
        return [menus('$calls')];
      },
    );

    await authorization.allowedMenuCodes(sessionKey: 'session-a');
    await authorization.allowedMenuCodes(
      sessionKey: 'session-a',
      refresh: true,
    );
    authorization.clear();
    await authorization.allowedMenuCodes(sessionKey: 'session-a');

    expect(calls, 3);
  });

  test('does not cache a failed permission request', () async {
    var calls = 0;
    final authorization = NavigationRouteAuthorization(
      loadMenus: ({bool refresh = false}) {
        calls++;
        if (calls == 1) {
          return Future<List<NavigationMenuGroup>>.error(StateError('offline'));
        }
        return Future.value([menus('01003')]);
      },
    );

    await expectLater(
      authorization.allowedMenuCodes(sessionKey: 'session-a'),
      throwsStateError,
    );
    expect(await authorization.allowedMenuCodes(sessionKey: 'session-a'), {
      '01003',
    });
    expect(calls, 2);
  });
}
