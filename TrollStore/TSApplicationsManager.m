#import "TSApplicationsManager.h"
#import <TSUtil.h>
extern NSUserDefaults* trollStoreUserDefaults();

@implementation TSApplicationsManager

+ (instancetype)sharedInstance
{
    static TSApplicationsManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[TSApplicationsManager alloc] init];
    });
    return sharedInstance;
}

- (NSArray*)installedAppPaths
{
    return trollStoreInstalledAppBundlePaths();
}

- (NSError*)errorForCode:(int)code
{
    NSString* errorDescription = @"未知错误";
    switch(code)
    {
        // IPA 安装错误
        case 166:
            errorDescription = @"IPA 文件不存在或无法访问。";
            break;
        case 167:
            errorDescription = @"IPA 文件似乎不包含应用程序。";
            break;
        case 168:
            errorDescription = @"提取 IPA 文件失败。";
            break;
        case 169:
            errorDescription = @"提取更新 tar 文件失败。";
            break;
        // 应用程序安装错误
        case 170:
            errorDescription = @"无法为应用程序包创建容器。";
            break;
        case 171:
            errorDescription = @"已经安装了具有相同标识符的非 TrollStore 应用程序。如果您确信没有安装, 请尝试强制安装。";
            break;
        case 172:
            errorDescription = @"应用程序不包含 Info.plist 文件。";
            break;
        case 173:
            errorDescription = @"应用程序未使用假 CoreTrust 证书进行签名, 且未安装 ldid。请在设置选项卡中安装 ldid 并重试。";
            break;
        case 174:
            errorDescription = @"应用程序的主执行文件不存在。";
            break;
        case 175: {
            //if (@available(iOS 16, *)) {
            //    errorDescription = @"Failed to sign the app.";
            //}
            //else {
                errorDescription = @"应用程序签名失败。ldid 返回非 0 状态码。";
            //}
            break;
        }
        case 176:
            errorDescription = @"应用程序的 Info.plist 缺少必需的值。";
            break;
        case 177:
            errorDescription = @"将应用程序标记为 TrollStore 应用程序失败。";
            break;
        case 178:
            errorDescription = @"复制应用程序包失败。";
            break;
        case 179:
            errorDescription = @"您尝试安装的应用程序与设备上已安装的系统应用程序具有相同的标识符。阻止安装以防止可能的启动循环或其他问题。";
            break;
        case 180:
            errorDescription = @"您尝试安装的应用程序具有加密的主要二进制文件, 无法应用 CoreTrust 绕过。请确保安装解密的应用程序。";
            break;
        case 181:
            errorDescription = @"将应用程序添加到图标缓存失败。";
            break;
        case 182:
            errorDescription = @"应用程序安装成功, 但需要启用开发者模式才能运行。重启后, 选择 \"打开\" 以启用开发者模式。";
            break;
        case 183:
            errorDescription = @"启用开发者模式失败。";
            break;
        case 184:
            errorDescription = @"应用程序安装成功, 但具有其他加密的二进制文件（例如扩展、插件）。应用程序本身应该可以工作, 但可能会导致功能损坏。";
            break;
    }

    NSError* error = [NSError errorWithDomain:TrollStoreErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey : errorDescription}];
    return error;
}

- (int)installIpa:(NSString*)pathToIpa force:(BOOL)force log:(NSString**)logOut
{
    NSMutableArray* args = [NSMutableArray new];
    [args addObject:@"install"];
    if(force)
    {
        [args addObject:@"force"];
    }
    NSNumber* installationMethodToUseNum = [trollStoreUserDefaults() objectForKey:@"installationMethod"];
    int installationMethodToUse = installationMethodToUseNum ? installationMethodToUseNum.intValue : 1;
    if(installationMethodToUse == 1)
    {
        [args addObject:@"custom"];
    }
    else
    {
        [args addObject:@"installd"];
    }
    [args addObject:pathToIpa];

    int ret = spawnRoot(rootHelperPath(), args, nil, logOut);
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ApplicationsChanged" object:nil];
    return ret;
}

- (int)installIpa:(NSString*)pathToIpa
{
    return [self installIpa:pathToIpa force:NO log:nil];
}

- (int)uninstallApp:(NSString*)appId
{
    if(!appId) return -200;

    NSMutableArray* args = [NSMutableArray new];
    [args addObject:@"uninstall"];

    NSNumber* uninstallationMethodToUseNum = [trollStoreUserDefaults() objectForKey:@"uninstallationMethod"];
    int uninstallationMethodToUse = uninstallationMethodToUseNum ? uninstallationMethodToUseNum.intValue : 0;
    if(uninstallationMethodToUse == 1)
    {
        [args addObject:@"custom"];
    }
    else
    {
        [args addObject:@"installd"];
    }

    [args addObject:appId];

    int ret = spawnRoot(rootHelperPath(), args, nil, nil);
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ApplicationsChanged" object:nil];
    return ret;
}

- (int)uninstallAppByPath:(NSString*)path
{
    if(!path) return -200;

    NSMutableArray* args = [NSMutableArray new];
    [args addObject:@"uninstall-path"];

    NSNumber* uninstallationMethodToUseNum = [trollStoreUserDefaults() objectForKey:@"uninstallationMethod"];
    int uninstallationMethodToUse = uninstallationMethodToUseNum ? uninstallationMethodToUseNum.intValue : 0;
    if(uninstallationMethodToUse == 1)
    {
        [args addObject:@"custom"];
    }
    else
    {
        [args addObject:@"installd"];
    }

    [args addObject:path];

    int ret = spawnRoot(rootHelperPath(), args, nil, nil);
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ApplicationsChanged" object:nil];
    return ret;
}

- (BOOL)openApplicationWithBundleID:(NSString *)appId
{
    return [[LSApplicationWorkspace defaultWorkspace] openApplicationWithBundleID:appId];
}

- (int)enableJITForBundleID:(NSString *)appId
{
    return spawnRoot(rootHelperPath(), @[@"enable-jit", appId], nil, nil);
}

- (int)changeAppRegistration:(NSString*)appPath toState:(NSString*)newState
{
    if(!appPath || !newState) return -200;
    return spawnRoot(rootHelperPath(), @[@"modify-registration", appPath, newState], nil, nil);
}

@end