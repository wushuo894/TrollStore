#import "TSAppTableViewController.h"

#import "TSApplicationsManager.h"
#import <TSPresentationDelegate.h>
#import "TSInstallationController.h"
#import "TSUtil.h"
@import UniformTypeIdentifiers;

#define ICON_FORMAT_IPAD 8
#define ICON_FORMAT_IPHONE 10

NSInteger iconFormatToUse(void)
{
	if(UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad)
	{
		return ICON_FORMAT_IPAD;
	}
	else
	{
		return ICON_FORMAT_IPHONE;
	}
}

UIImage* imageWithSize(UIImage* image, CGSize size)
{
	if(CGSizeEqualToSize(image.size, size)) return image;
	UIGraphicsBeginImageContextWithOptions(size, NO, UIScreen.mainScreen.scale);
	CGRect imageRect = CGRectMake(0.0, 0.0, size.width, size.height);
	[image drawInRect:imageRect];
	UIImage* outImage = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return outImage;
}

@interface UIImage ()
+ (UIImage *)_applicationIconImageForBundleIdentifier:(NSString *)id format:(NSInteger)format scale:(double)scale;
@end

@implementation TSAppTableViewController

- (void)loadAppInfos
{
	NSArray* appPaths = [[TSApplicationsManager sharedInstance] installedAppPaths];
	NSMutableArray<TSAppInfo*>* appInfos = [NSMutableArray new];

	for(NSString* appPath in appPaths)
	{
		TSAppInfo* appInfo = [[TSAppInfo alloc] initWithAppBundlePath:appPath];
		[appInfo sync_loadBasicInfo];
		[appInfos addObject:appInfo];
	}

	if(_searchKey && ![_searchKey isEqualToString:@""])
	{
		[appInfos enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(TSAppInfo* appInfo, NSUInteger idx, BOOL* stop)
		{
			NSString* appName = [appInfo displayName];
			BOOL nameMatch = [appName rangeOfString:_searchKey options:NSCaseInsensitiveSearch range:NSMakeRange(0, [appName length]) locale:[NSLocale currentLocale]].location != NSNotFound;
			if(!nameMatch)
			{
				[appInfos removeObjectAtIndex:idx];
			}
		}];
	}

	[appInfos sortUsingComparator:^(TSAppInfo* appInfoA, TSAppInfo* appInfoB)
	{
		return [[appInfoA displayName] localizedStandardCompare:[appInfoB displayName]];
	}];

	_cachedAppInfos = appInfos.copy;
}

- (instancetype)init
{
	self = [super init];
	if(self)
	{
		[self loadAppInfos];
		_placeholderIcon = [UIImage _applicationIconImageForBundleIdentifier:@"com.apple.WebSheet" format:iconFormatToUse() scale:[UIScreen mainScreen].scale];
		_cachedIcons = [NSMutableDictionary new];
		[[LSApplicationWorkspace defaultWorkspace] addObserver:self];
	}
	return self;
}

- (void)dealloc
{
	[[LSApplicationWorkspace defaultWorkspace] removeObserver:self];
}

- (void)reloadTable
{
	[self loadAppInfos];
	dispatch_async(dispatch_get_main_queue(), ^
	{
		[self.tableView reloadData];
	});
}

- (void)loadView
{
	[super loadView];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadTable) name:@"ApplicationsChanged" object:nil];
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	self.tableView.allowsMultipleSelectionDuringEditing = NO;
	self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];

	[self _setUpNavigationBar];
	[self _setUpSearchBar];
}

- (void)_setUpNavigationBar
{
	UIAction* installFromFileAction = [UIAction actionWithTitle:@"安装 IPA 文件" image:[UIImage systemImageNamed:@"doc.badge.plus"] identifier:@"InstallIPAFile" handler:^(__kindof UIAction *action)
	{
		dispatch_async(dispatch_get_main_queue(), ^
		{
			UTType* ipaType = [UTType typeWithFilenameExtension:@"ipa" conformingToType:UTTypeData];
			UTType* tipaType = [UTType typeWithFilenameExtension:@"tipa" conformingToType:UTTypeData];

			UIDocumentPickerViewController* documentPickerVC = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[ipaType, tipaType]];
			documentPickerVC.allowsMultipleSelection = NO;
			documentPickerVC.delegate = self;

			[TSPresentationDelegate presentViewController:documentPickerVC animated:YES completion:nil];
		});
	}];

	UIAction* installFromURLAction = [UIAction actionWithTitle:@"通过链接安装" image:[UIImage systemImageNamed:@"link.badge.plus"] identifier:@"InstallFromURL" handler:^(__kindof UIAction *action)
	{
		dispatch_async(dispatch_get_main_queue(), ^
		{
			UIAlertController* installURLController = [UIAlertController alertControllerWithTitle:@"安装地址" message:@"" preferredStyle:UIAlertControllerStyleAlert];

			[installURLController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
				textField.placeholder = @"URL";
			}];

			UIAlertAction* installAction = [UIAlertAction actionWithTitle:@"安装" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action)
			{
				NSString* URLString = installURLController.textFields.firstObject.text;
				NSURL* remoteURL = [NSURL URLWithString:URLString];

				[TSInstallationController handleAppInstallFromRemoteURL:remoteURL completion:nil];
			}];
			[installURLController addAction:installAction];

			UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
			[installURLController addAction:cancelAction];

			[TSPresentationDelegate presentViewController:installURLController animated:YES completion:nil];
		});
	}];

	UIMenu* installMenu = [UIMenu menuWithChildren:@[installFromFileAction, installFromURLAction]];

	UIBarButtonItem* installBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"plus"] menu:installMenu];
	
	self.navigationItem.rightBarButtonItems = @[installBarButtonItem];
}

- (void)_setUpSearchBar
{
	_searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
	_searchController.searchResultsUpdater = self;
	_searchController.obscuresBackgroundDuringPresentation = NO;
	self.navigationItem.searchController = _searchController;
	self.navigationItem.hidesSearchBarWhenScrolling = YES;
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController
{
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		_searchKey = searchController.searchBar.text;
		[self reloadTable];
	});
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls
{
	NSString* pathToIPA = urls.firstObject.path;
	[TSInstallationController presentInstallationAlertIfEnabledForFile:pathToIPA isRemoteInstall:NO completion:nil];
}

- (void)openAppPressedForRowAtIndexPath:(NSIndexPath*)indexPath enableJIT:(BOOL)enableJIT
{
	TSApplicationsManager* appsManager = [TSApplicationsManager sharedInstance];

	TSAppInfo* appInfo = _cachedAppInfos[indexPath.row];
	NSString* appId = [appInfo bundleIdentifier];
	BOOL didOpen = [appsManager openApplicationWithBundleID:appId];

	// if we failed to open the app, show an alert
	if(!didOpen)
	{
		NSString* failMessage = @"";
		if([[appInfo registrationState] isEqualToString:@"User"])
		{
			failMessage = @"这个应用程序无法启动, 因为它具有\"User\"注册状态, 请将其注册为\"System\"后重试。";
		}

		NSString* failTitle = [NSString stringWithFormat:@"打开失败 %@", appId];
		UIAlertController* didFailController = [UIAlertController alertControllerWithTitle:failTitle message:failMessage preferredStyle:UIAlertControllerStyleAlert];
		UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];

		[didFailController addAction:cancelAction];
		[TSPresentationDelegate presentViewController:didFailController animated:YES completion:nil];
	}
	else if (enableJIT)
	{
		int ret = [appsManager enableJITForBundleID:appId];
		if (ret != 0)
		{
			UIAlertController* errorAlert = [UIAlertController alertControllerWithTitle:@"错误" message:[NSString stringWithFormat:@"启用 JIT 错误：trollstorehelper 返回错误 %d", ret] preferredStyle:UIAlertControllerStyleAlert];
			UIAlertAction* closeAction = [UIAlertAction actionWithTitle:@"关闭" style:UIAlertActionStyleDefault handler:nil];
			[errorAlert addAction:closeAction];
			[TSPresentationDelegate presentViewController:errorAlert animated:YES completion:nil];
		}
	}
}

- (void)showDetailsPressedForRowAtIndexPath:(NSIndexPath*)indexPath
{
	TSAppInfo* appInfo = _cachedAppInfos[indexPath.row];

	[appInfo loadInfoWithCompletion:^(NSError* error)
	{
		dispatch_async(dispatch_get_main_queue(), ^
		{
			if(!error)
			{
				UIAlertController* detailsAlert = [UIAlertController alertControllerWithTitle:@"" message:@"" preferredStyle:UIAlertControllerStyleAlert];
				detailsAlert.attributedTitle = [appInfo detailedInfoTitle];
				detailsAlert.attributedMessage = [appInfo detailedInfoDescription];

				UIAlertAction* closeAction = [UIAlertAction actionWithTitle:@"关闭" style:UIAlertActionStyleDefault handler:nil];
				[detailsAlert addAction:closeAction];

				[TSPresentationDelegate presentViewController:detailsAlert animated:YES completion:nil];
			}
			else
			{
				UIAlertController* errorAlert = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"解析错误 %ld", error.code] message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
				UIAlertAction* closeAction = [UIAlertAction actionWithTitle:@"关闭" style:UIAlertActionStyleDefault handler:nil];
				[errorAlert addAction:closeAction];

				[TSPresentationDelegate presentViewController:errorAlert animated:YES completion:nil];
			}
		});
	}];
}

- (void)changeAppRegistrationForRowAtIndexPath:(NSIndexPath*)indexPath toState:(NSString*)newState
{
	TSAppInfo* appInfo = _cachedAppInfos[indexPath.row];

	if([newState isEqualToString:@"User"])
	{
		NSString* title = [NSString stringWithFormat:@"已将 '%@' 切换为 \"System\" 注册状态", [appInfo displayName]];
		UIAlertController* confirmationAlert = [UIAlertController alertControllerWithTitle:title message:@"将此应用程序切换为 \"User\" 注册状态后, 下次重新启动后将无法启动, 因为 TrollStore 中利用的漏洞仅影响注册为 \"System\" 的应用程序。\n此选项的目的是使应用程序暂时显示在设置中, 以便您可以调整设置, 然后将其切换回 \"System\" 注册状态（否则, TrollStore 安装的应用程序不会显示在设置中）。此外, \"User\" 注册状态还可以临时修复 iTunes 文件共享, 否则 TrollStore 安装的应用程序无法正常工作。\n当您完成所需的更改并希望应用程序能够再次启动时, 您需要在 TrollStore 中将其切换回 \"System\" 状态。" preferredStyle:UIAlertControllerStyleAlert];

		UIAlertAction* switchToUserAction = [UIAlertAction actionWithTitle:@"切换为 \"User\"" style:UIAlertActionStyleDestructive handler:^(UIAlertAction* action)
		{
			[[TSApplicationsManager sharedInstance] changeAppRegistration:[appInfo bundlePath] toState:newState];
			[appInfo sync_loadBasicInfo];
		}];

		[confirmationAlert addAction:switchToUserAction];

		UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];

		[confirmationAlert addAction:cancelAction];

		[TSPresentationDelegate presentViewController:confirmationAlert animated:YES completion:nil];
	}
	else
	{
		[[TSApplicationsManager sharedInstance] changeAppRegistration:[appInfo bundlePath] toState:newState];
		[appInfo sync_loadBasicInfo];

		NSString* title = [NSString stringWithFormat:@"已将 '%@' 切换为 \"System\" 注册状态", [appInfo displayName]];

		UIAlertController* infoAlert = [UIAlertController alertControllerWithTitle:title message:@"该应用程序已切换到 \"System\" 注册状态, 在软重启后生效" preferredStyle:UIAlertControllerStyleAlert];

		UIAlertAction* respringAction = [UIAlertAction actionWithTitle:@"软重启" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action)
		{
			respring();
		}];

		[infoAlert addAction:respringAction];

		UIAlertAction* closeAction = [UIAlertAction actionWithTitle:@"关闭" style:UIAlertActionStyleDefault handler:nil];

		[infoAlert addAction:closeAction];

		[TSPresentationDelegate presentViewController:infoAlert animated:YES completion:nil];
	}
}

- (void)uninstallPressedForRowAtIndexPath:(NSIndexPath*)indexPath
{
	TSApplicationsManager* appsManager = [TSApplicationsManager sharedInstance];

	TSAppInfo* appInfo = _cachedAppInfos[indexPath.row];

	NSString* appPath = [appInfo bundlePath];
	NSString* appId = [appInfo bundleIdentifier];
	NSString* appName = [appInfo displayName];

	UIAlertController* confirmAlert = [UIAlertController alertControllerWithTitle:@"确认卸载操作" message:[NSString stringWithFormat:@"卸载应用程序 '%@' 将删除该应用程序及其关联的所有数据。", appName] preferredStyle:UIAlertControllerStyleAlert];

	UIAlertAction* uninstallAction = [UIAlertAction actionWithTitle:@"卸载" style:UIAlertActionStyleDestructive handler:^(UIAlertAction* action)
	{
		if(appId)
		{
			[appsManager uninstallApp:appId];
		}
		else
		{
			[appsManager uninstallAppByPath:appPath];
		}
	}];
	[confirmAlert addAction:uninstallAction];

	UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
	[confirmAlert addAction:cancelAction];

	[TSPresentationDelegate presentViewController:confirmAlert animated:YES completion:nil];
}

- (void)deselectRow
{
	[self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:YES];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return _cachedAppInfos.count;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
	[self reloadTable];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ApplicationCell"];
	if(!cell) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"ApplicationCell"];
	}

	if(!indexPath || indexPath.row > (_cachedAppInfos.count - 1)) return cell;

	TSAppInfo* appInfo = _cachedAppInfos[indexPath.row];
	NSString* appId = [appInfo bundleIdentifier];
	NSString* appVersion = [appInfo versionString];

	// Configure the cell...
	cell.textLabel.text = [appInfo displayName];
	cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ • %@", appVersion, appId];
	cell.imageView.layer.borderWidth = 1;
	cell.imageView.layer.borderColor = [UIColor.labelColor colorWithAlphaComponent:0.1].CGColor;
	cell.imageView.layer.cornerRadius = 13.5;
	cell.imageView.layer.masksToBounds = YES;
	cell.imageView.layer.cornerCurve = kCACornerCurveContinuous;

	if(appId)
	{
		UIImage* cachedIcon = _cachedIcons[appId];
		if(cachedIcon)
		{
			cell.imageView.image = cachedIcon;
		}
		else
		{
			cell.imageView.image = _placeholderIcon;
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^
			{
				UIImage* iconImage = imageWithSize([UIImage _applicationIconImageForBundleIdentifier:appId format:iconFormatToUse() scale:[UIScreen mainScreen].scale], _placeholderIcon.size);
				_cachedIcons[appId] = iconImage;
				dispatch_async(dispatch_get_main_queue(), ^{
					NSIndexPath *curIndexPath = [NSIndexPath indexPathForRow:[_cachedAppInfos indexOfObject:appInfo] inSection:0];
					UITableViewCell *curCell = [tableView cellForRowAtIndexPath:curIndexPath];
					if(curCell)
					{
						curCell.imageView.image = iconImage;
						[curCell setNeedsLayout];
					}
				});
			});
		}
	}
	else
	{
		cell.imageView.image = _placeholderIcon;
	}

	cell.preservesSuperviewLayoutMargins = NO;
	cell.separatorInset = UIEdgeInsetsZero;
	cell.layoutMargins = UIEdgeInsetsZero;

	return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return 80.0f;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
	if(editingStyle == UITableViewCellEditingStyleDelete)
	{
		[self uninstallPressedForRowAtIndexPath:indexPath];
	}
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	TSAppInfo* appInfo = _cachedAppInfos[indexPath.row];

	NSString* appId = [appInfo bundleIdentifier];
	NSString* appName = [appInfo displayName];

	UIAlertController* appSelectAlert = [UIAlertController alertControllerWithTitle:appName?:@"" message:appId?:@"" preferredStyle:UIAlertControllerStyleActionSheet];

	UIAlertAction* openAction = [UIAlertAction actionWithTitle:@"打开" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action)
	{
		[self openAppPressedForRowAtIndexPath:indexPath enableJIT:NO];
		[self deselectRow];
	}];
	[appSelectAlert addAction:openAction];

	if ([appInfo isDebuggable])
	{
		UIAlertAction* openWithJITAction = [UIAlertAction actionWithTitle:@"使用 JIT 打开" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action)
		{
			[self openAppPressedForRowAtIndexPath:indexPath enableJIT:YES];
			[self deselectRow];
		}];
		[appSelectAlert addAction:openWithJITAction];
	}

	UIAlertAction* showDetailsAction = [UIAlertAction actionWithTitle:@"显示详细信息" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action)
	{
		[self showDetailsPressedForRowAtIndexPath:indexPath];
		[self deselectRow];
	}];
	[appSelectAlert addAction:showDetailsAction];

	NSString* switchState;
	NSString* registrationState = [appInfo registrationState];
	UIAlertActionStyle switchActionStyle = 0;
	if([registrationState isEqualToString:@"System"])
	{
		switchState = @"User";
		switchActionStyle = UIAlertActionStyleDestructive;
	}
	else if([registrationState isEqualToString:@"User"])
	{
		switchState = @"System";
		switchActionStyle = UIAlertActionStyleDefault;
	}

	UIAlertAction* switchRegistrationAction = [UIAlertAction actionWithTitle:[NSString stringWithFormat:@"切换到 \"%@\" 注册状态", switchState] style:switchActionStyle handler:^(UIAlertAction* action)
	{
		[self changeAppRegistrationForRowAtIndexPath:indexPath toState:switchState];
		[self deselectRow];
	}];
	[appSelectAlert addAction:switchRegistrationAction];

	UIAlertAction* uninstallAction = [UIAlertAction actionWithTitle:@"卸载应用程序" style:UIAlertActionStyleDestructive handler:^(UIAlertAction* action)
	{
		[self uninstallPressedForRowAtIndexPath:indexPath];
		[self deselectRow];
	}];
	[appSelectAlert addAction:uninstallAction];

	UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction* action)
	{
		[self deselectRow];
	}];
	[appSelectAlert addAction:cancelAction];

	appSelectAlert.popoverPresentationController.sourceView = tableView;
	appSelectAlert.popoverPresentationController.sourceRect = [tableView rectForRowAtIndexPath:indexPath];

	[TSPresentationDelegate presentViewController:appSelectAlert animated:YES completion:nil];
}

- (void)purgeCachedIconsForApps:(NSArray <LSApplicationProxy *>*)apps
{
	for (LSApplicationProxy *appProxy in apps) {
		NSString *appId = appProxy.bundleIdentifier;
		if (_cachedIcons[appId]) {
			[_cachedIcons removeObjectForKey:appId];
		}
	}
}

- (void)applicationsDidInstall:(NSArray <LSApplicationProxy *>*)apps
{
	[self purgeCachedIconsForApps:apps];
	[self reloadTable];
}

- (void)applicationsDidUninstall:(NSArray <LSApplicationProxy *>*)apps
{
	[self purgeCachedIconsForApps:apps];
	[self reloadTable];
}

@end
