#import "TSSettingsAdvancedListController.h"
#import <Preferences/PSSpecifier.h>

extern NSUserDefaults* trollStoreUserDefaults();
@interface PSSpecifier ()
@property (nonatomic,retain) NSArray* values;
@end

@implementation TSSettingsAdvancedListController

- (NSMutableArray*)specifiers
{
	if(!_specifiers)
	{
		_specifiers = [NSMutableArray new];

		PSSpecifier* installationMethodGroupSpecifier = [PSSpecifier emptyGroupSpecifier];
		//installationMethodGroupSpecifier.name = @"Installation";
		[installationMethodGroupSpecifier setProperty:@"installd: \n通过使用 installd 进行占位安装、修复权限, 然后将应用程序添加到图标缓存来安装应用程序。\n优点: 在图标缓存重新加载方面可能比自定义方法稍微持久。\n缺点: 对某些应用程序可能会出现一些小问题, 原因似乎无法解释(例如, 使用此方法安装 Watusi 时无法保存首选项)。\n\n自定义(推荐): \n通过使用 MobileContainerManager 手动创建捆绑包, 将应用程序复制到其中并将其添加到图标缓存中来安装应用程序。\n优点: 没有已知问题(与 installd 方法中概述的 Watusi 问题相对)。\n缺点: 在图标缓存重新加载方面可能比 installd 方法稍微不持久。\n\n注意: 如果选择了 installd 但占位安装失败, TrollStore 会自动回退到使用自定义方法。" forKey:@"footerText"];
		[_specifiers addObject:installationMethodGroupSpecifier];

		PSSpecifier* installationMethodSpecifier = [PSSpecifier preferenceSpecifierNamed:@"安装模式"
											target:self
											set:nil
											get:nil
											detail:nil
											cell:PSStaticTextCell
											edit:nil];
		[installationMethodSpecifier setProperty:@YES forKey:@"enabled"];
		installationMethodSpecifier.identifier = @"installationMethodLabel";
		[_specifiers addObject:installationMethodSpecifier];

		PSSpecifier* installationMethodSegmentSpecifier = [PSSpecifier preferenceSpecifierNamed:@"Installation Method Segment"
											target:self
											set:@selector(setPreferenceValue:specifier:)
											get:@selector(readPreferenceValue:)
											detail:nil
											cell:PSSegmentCell
											edit:nil];
		[installationMethodSegmentSpecifier setProperty:@YES forKey:@"enabled"];
		installationMethodSegmentSpecifier.identifier = @"installationMethodSegment";
		[installationMethodSegmentSpecifier setProperty:@"com.opa334.TrollStore" forKey:@"defaults"];
		[installationMethodSegmentSpecifier setProperty:@"installationMethod" forKey:@"key"];
		installationMethodSegmentSpecifier.values = @[@0, @1];
		installationMethodSegmentSpecifier.titleDictionary = @{@0 : @"installd", @1 : @"Custom"};
		[installationMethodSegmentSpecifier setProperty:@1 forKey:@"default"];
		[_specifiers addObject:installationMethodSegmentSpecifier];

		PSSpecifier* uninstallationMethodGroupSpecifier = [PSSpecifier emptyGroupSpecifier];
		//uninstallationMethodGroupSpecifier.name = @"Uninstallation";
		[uninstallationMethodGroupSpecifier setProperty:@"installd (推荐): \n使用与 SpringBoard 在从主屏幕卸载应用程序时相同的 API 来卸载应用程序。\n\n自定义: \n通过从图标缓存中删除应用程序, 然后直接删除其应用程序和数据捆绑包来卸载应用程序。\n\n注意: 如果选择了 installd, 但默认的卸载失败, TrollStore 会自动回退到使用自定义方法。" forKey:@"footerText"];
		[_specifiers addObject:uninstallationMethodGroupSpecifier];

		PSSpecifier* uninstallationMethodSpecifier = [PSSpecifier preferenceSpecifierNamed:@"卸载模式"
											target:self
											set:nil
											get:nil
											detail:nil
											cell:PSStaticTextCell
											edit:nil];
		[uninstallationMethodSpecifier setProperty:@YES forKey:@"enabled"];
		uninstallationMethodSpecifier.identifier = @"uninstallationMethodLabel";
		[_specifiers addObject:uninstallationMethodSpecifier];

		PSSpecifier* uninstallationMethodSegmentSpecifier = [PSSpecifier preferenceSpecifierNamed:@"Installation Method Segment"
											target:self
											set:@selector(setPreferenceValue:specifier:)
											get:@selector(readPreferenceValue:)
											detail:nil
											cell:PSSegmentCell
											edit:nil];
		[uninstallationMethodSegmentSpecifier setProperty:@YES forKey:@"enabled"];
		uninstallationMethodSegmentSpecifier.identifier = @"uninstallationMethodSegment";
		[uninstallationMethodSegmentSpecifier setProperty:@"com.opa334.TrollStore" forKey:@"defaults"];
		[uninstallationMethodSegmentSpecifier setProperty:@"uninstallationMethod" forKey:@"key"];
		uninstallationMethodSegmentSpecifier.values = @[@0, @1];
		uninstallationMethodSegmentSpecifier.titleDictionary = @{@0 : @"installd", @1 : @"Custom"};
		[uninstallationMethodSegmentSpecifier setProperty:@0 forKey:@"default"];
		[_specifiers addObject:uninstallationMethodSegmentSpecifier];
	}

	[(UINavigationItem *)self.navigationItem setTitle:@"Advanced"];
	return _specifiers;
}

- (void)setPreferenceValue:(NSObject*)value specifier:(PSSpecifier*)specifier
{
	NSUserDefaults* tsDefaults = trollStoreUserDefaults();
	[tsDefaults setObject:value forKey:[specifier propertyForKey:@"key"]];
}

- (NSObject*)readPreferenceValue:(PSSpecifier*)specifier
{
	NSUserDefaults* tsDefaults = trollStoreUserDefaults();
	NSObject* toReturn = [tsDefaults objectForKey:[specifier propertyForKey:@"key"]];
	if(!toReturn)
	{
		toReturn = [specifier propertyForKey:@"default"];
	}
	return toReturn;
}

@end
