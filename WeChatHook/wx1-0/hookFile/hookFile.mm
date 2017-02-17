#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "CaptainHook/CaptainHook.h"

// Objective-C runtime hooking using CaptainHook:
//   1. declare class using CHDeclareClass()
//   2. load class using CHLoadClass() or CHLoadLateClass() in CHConstructor
//   3. hook method using CHOptimizedMethod()
//   4. register hook using CHHook() in CHConstructor
//   5. (optionally) call old method using CHSuper()

/******************************************微信转发功能**********************************************************/
/**
 *  转发小视频至（朋友圈+朋友+保存到相册）
 **/

@class WCContentItemViewTemplateNewSight;
static int MenuShowCount = 0;
CHDeclareClass(WCContentItemViewTemplateNewSight); // declare class
//定义新方法，拿到小视频的WCMediaItem
CHDeclareMethod0(id, WCContentItemViewTemplateNewSight, SLSightDataItem)
{
    id responder = self;
    id SightCell = [[objc_getClass("MMTableViewCell") performSelector:@selector(alloc)] performSelector:@selector(init)];
    id SightTableView = [[objc_getClass("SightTableView") performSelector:@selector(alloc)] performSelector:@selector(init)];
    while (![responder isKindOfClass:NSClassFromString(@"WCTimeLineViewController")])
    {
        if ([responder isKindOfClass:NSClassFromString(@"MMTableViewCell")]){
            SightCell = responder;
        }
        else if ([responder isKindOfClass:NSClassFromString(@"MMTableView")]){
            SightTableView = responder;
        }
        responder = [responder performSelector:@selector(nextResponder) withObject:nil];
    }
    id WCTimelineVC = responder;
    NSIndexPath *indexPath = [SightTableView performSelector:@selector(indexPathForCell:) withObject:SightCell];
    long long sectionindex = (long long)[indexPath performSelector:@selector(section) withObject:nil];
    long long itemIndex = ((long long(*)(id,SEL,long long))objc_msgSend)(WCTimelineVC, @selector(calcDataItemIndex:), sectionindex);//经测试long long的参数类型不可以用id，否则会崩溃
    //微信服务中心
    Method MMServerMethod = class_getClassMethod(objc_getClass("MMServiceCenter"), @selector(defaultCenter));
    IMP MMServerImp = method_getImplementation(MMServerMethod);
    id MMServerCenter = MMServerImp(objc_getClass("MMServiceCenter"), @selector(defaultCenter));
    id facade = ((id(*)(id,SEL,Class))objc_msgSend)(MMServerCenter, @selector(getService:), objc_getClass("WCFacade"));
    id dataItem = ((id(*)(id,SEL,long long))objc_msgSend)(facade, @selector(getTimelineDataItemOfIndex:), itemIndex);
    id contentItem = [dataItem valueForKey:@"contentObj"];
    id mediaItem = [[contentItem valueForKey:@"mediaList" ] performSelector:@selector(objectAtIndex:) withObject:0];
    return mediaItem;
}

//保存小视频到本地
CHDeclareMethod0(void, WCContentItemViewTemplateNewSight, SLSightSaveToDisk)
{
    id dataItem = [self performSelector:@selector(SLSightDataItem)];//小视频的MediaItem
    NSString *localPath = [dataItem performSelector:@selector(pathForSightData) withObject:nil];
    UISaveVideoAtPathToSavedPhotosAlbum(localPath, nil, nil, nil);
}

//复制小视频链接
CHDeclareMethod0(void, WCContentItemViewTemplateNewSight, SLSightCopyUrl)
{
    id dataItem = objc_msgSend(self, @selector(SLSightDataItem));//小视频的MediaItem
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    pasteboard.string = [[dataItem valueForKey:@"dataUrl"] valueForKey:@"url"];
}

//转发小视频到朋友圈
CHDeclareMethod0(void, WCContentItemViewTemplateNewSight, SLRetweetSight)
{
    id editSightVC = [[objc_getClass("SightMomentEditViewController") performSelector:@selector(alloc)] performSelector:@selector(init)];
    id dataItem = objc_msgSend(self, @selector(SLSightDataItem));//小视频的MediaItem
    NSString *localPath = [dataItem performSelector:@selector(pathForSightData)];
    UIImage *image = [[self valueForKey:@"_sightView"] performSelector:@selector(getImage)];
    [editSightVC setValue:localPath forKey:@"realMoviePath"];
    [editSightVC setValue:localPath forKey:@"moviePath"];
    [editSightVC setValue:image forKey:@"realThumbImage"];
    [editSightVC setValue:image forKey:@"thumbImage"];
    [[self performSelector:@selector(SLTimeLineController)] presentViewController:editSightVC animated:YES completion:^{
        
    }];
}

//转发小视频给朋友
CHDeclareMethod0(void, WCContentItemViewTemplateNewSight, SLSightSendToFriends)
{
    [self performSelector:@selector(sendSightToFriend)];
}


//获得当前TimeLine控制器
CHDeclareMethod0(id, WCContentItemViewTemplateNewSight, SLTimeLineController)
{
    id responder = self;
    while (![responder isKindOfClass:NSClassFromString(@"WCTimeLineViewController")])
    {
        responder = [responder performSelector:@selector(nextResponder) withObject:nil];
    }
    return responder;
}

CHOptimizedMethod0(self, void, WCContentItemViewTemplateNewSight, onLongTouch) // hook method (with no arguments and no return value)
{
    MenuShowCount++;
    if (MenuShowCount % 2 != 0) return;
    UIMenuController *menuController = [UIMenuController sharedMenuController];
    if (menuController.isMenuVisible) return;//防止出现menu闪屏的情况
    [self performSelector:@selector(becomeFirstResponder) withObject:nil];
    id dataItem = [self performSelector:@selector(SLSightDataItem) withObject:nil];//小视频的MediaItem
    NSString *localPath = [dataItem performSelector:@selector(pathForSightData) withObject:nil];//小视频的本地路径
    BOOL isExist =[[NSFileManager defaultManager] fileExistsAtPath:localPath];
    UIMenuItem *retweetMenuItem = [[UIMenuItem alloc] initWithTitle:@"朋友圈" action:@selector(SLRetweetSight)];
    UIMenuItem *saveToDiskMenuItem = [[UIMenuItem alloc] initWithTitle:@"保存到相册" action:@selector(SLSightSaveToDisk)];
    UIMenuItem *sendToFriendsMenuItem = [[UIMenuItem alloc] initWithTitle:@"好友" action:@selector(SLSightSendToFriends)];
    UIMenuItem *copyURLMenuItem = [[UIMenuItem alloc] initWithTitle:@"复制链接" action:@selector(SLSightCopyUrl)];
    if(isExist){
        [menuController setMenuItems:@[retweetMenuItem,sendToFriendsMenuItem,saveToDiskMenuItem,copyURLMenuItem]];
    }else{
        [menuController setMenuItems:@[copyURLMenuItem]];
    }
    [menuController setTargetRect:CGRectMake(0, 0, 0, 0) inView:(UIView *)self];
    [menuController setMenuVisible:YES animated:YES];
}

@class SightMomentEditViewController;
CHDeclareClass(SightMomentEditViewController);//小视频转发返回要pop控制器
CHOptimizedMethod0(self, void, SightMomentEditViewController, popSelf)
{
    [self dismissViewControllerAnimated:YES completion:^{
        
    }];
}

/******************************************微信修改运动步数**********************************************************/
#define SAVESETTINGS(key, value, fileName) { \
NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES); \
NSString *docDir = [paths objectAtIndex:0]; \
if (!docDir){ return;} \
NSMutableDictionary *dict = [NSMutableDictionary dictionary]; \
NSString *path = [docDir stringByAppendingPathComponent:fileName]; \
[dict setObject:value forKey:key]; \
[dict writeToFile:path atomically:YES]; \
}

static int StepCount = 6666;
static NSString *WeRunStepKey = @"WeRunStepKey";
static NSString *WeRunSettingFile = @"WeRunSettingFile.txt";
static NSString *HBPluginTypeKey = @"HBPluginType";
static NSString *HBPluginDelayKey = @"HBPluginDelay";
static NSString *HBPluginSettingFile = @"HBPluginSettingFile.txt";
static NSString *HBPluginDelaySettingFile = @"HBPluginDelaySettingFile.txt";

//这里只是修改微信运动的步数，步数的设置放在放在抢红包功能（普通消息处理）里面
CHDeclareClass(WCDeviceStepObject)
CHMethod0(unsigned int, WCDeviceStepObject, m7StepCount) {
    NSString *docDir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    NSMutableDictionary *dic = [NSMutableDictionary dictionaryWithContentsOfFile:[docDir stringByAppendingPathComponent:WeRunSettingFile]];
    if (!dic){ return StepCount;}
    int value = ((NSNumber *)dic[WeRunStepKey]).intValue;
    if (value < 0) {
        return CHSuper(0, WCDeviceStepObject, m7StepCount);
    }
    return value;
}

/******************************************微信自动抢红包**********************************************************/
static int const kCloseRedEnvPlugin = 0;//关闭红包插件
static int const kOpenRedEnvPlugin = 1;//打开红包插件
static int const kCloseRedEnvPluginForMyself = 2;//不抢自己的红包
static int const kCloseRedEnvPluginForMyselfFromChatroom = 3;//不抢群里自己发的红包
static int HBPluginType = 0;
static float HBPluginDelay=0.7;

CHDeclareClass(CMessageMgr);
/******************************************无视消息撤回**********************************************************/
CHMethod1(void, CMessageMgr, onRevokeMsg, id, arg1){
    return;
}

CHMethod2(void, CMessageMgr, AddMsg, id, arg1, MsgWrap, id, arg2){
    Ivar uiMessageTypeIvar = class_getInstanceVariable(objc_getClass("CMessageWrap"), "m_uiMessageType");
    ptrdiff_t offset = ivar_getOffset(uiMessageTypeIvar);
    unsigned char *stuffBytes = (unsigned char *)(__bridge void *)arg2;
    NSUInteger m_uiMessageType = * ((NSUInteger *)(stuffBytes + offset));
    
    Ivar nsFromUsrIvar = class_getInstanceVariable(objc_getClass("CMessageWrap"), "m_nsFromUsr");
    id m_nsFromUsr = object_getIvar(arg2, nsFromUsrIvar);
    Ivar nsToUsrIvar = class_getInstanceVariable(objc_getClass("CMessageWrap"), "m_nsToUsr");
    id m_nsToUsr = object_getIvar(arg2, nsToUsrIvar);
    
    Ivar nsContentIvar = class_getInstanceVariable(objc_getClass("CMessageWrap"), "m_nsContent");
    id m_nsContent = object_getIvar(arg2, nsContentIvar);
    Ivar nsMsgSource = class_getInstanceVariable(objc_getClass("CMessageWrap"), "m_nsMsgSource");
    id m_nsMsgSource = object_getIvar(arg2, nsMsgSource);
    BOOL isFind=NO;
    //判断是否自己给自己发消息
    if ([m_nsFromUsr isEqualToString:m_nsToUsr])
    {
        //并且是文字消息
        if (m_uiMessageType == 1) {
            if ([m_nsContent isEqualToString:@"打开红包插件"])
            {
                HBPluginType = kOpenRedEnvPlugin;
                m_nsContent=@"肥大大微信Tips:已打开红包插件";
                isFind=YES;
            }
            else if ([m_nsContent isEqualToString:@"关闭红包插件"])
            {
                HBPluginType = kCloseRedEnvPlugin;
                m_nsContent=@"肥大大微信Tips:已关闭红包插件";
                isFind=YES;
            }
            else if ([m_nsContent isEqualToString:@"关闭抢自己红包"])
            {
                HBPluginType = kCloseRedEnvPluginForMyself;
                m_nsContent=@"肥大大微信Tips:已关闭抢自己红包";
                isFind=YES;
            }
            else if ([m_nsContent isEqualToString:@"关闭抢群红包"])
            {
                HBPluginType = kCloseRedEnvPluginForMyselfFromChatroom;
                m_nsContent=@"肥大大微信Tips:已关闭抢自己群红包";
                isFind=YES;
            }
            else if ([m_nsContent rangeOfString:@"抢红包延迟#"].location != NSNotFound)
            {
                NSArray *array = [m_nsContent componentsSeparatedByString:@"#"];
                if (array.count == 2) {
                    HBPluginDelay = ((NSNumber *)array[1]).floatValue;
                }
                m_nsContent=[NSString stringWithFormat:@"肥大大微信Tips:成功修改抢红包延迟:%.2f秒",HBPluginDelay];
                isFind=YES;
            }
            else if ([m_nsContent rangeOfString:@"修改微信步数#"].location != NSNotFound)
            {
                NSArray *array = [m_nsContent componentsSeparatedByString:@"#"];
                if (array.count == 2) {
                    StepCount = ((NSNumber *)array[1]).intValue;
                }
                m_nsContent=@"肥大大微信Tips:成功修改微信步数";
                isFind=YES;
                //保存修改微信步数设置
                SAVESETTINGS(WeRunStepKey, [NSNumber numberWithInt:StepCount], WeRunSettingFile)
            } else if([m_nsContent isEqualToString:@"恢复微信步数"]) {
                StepCount = -1;
                m_nsContent=@"肥大大微信Tips:恢复微信步数";
                isFind=YES;
                //保存修改微信步数设置
                SAVESETTINGS(WeRunStepKey, [NSNumber numberWithInt:StepCount], WeRunSettingFile)
            }else if([m_nsContent isEqualToString:@"使用说明"]) {
                m_nsContent=@"=欢迎使用肥大大微信V1.0=\n此版本包含功能：自动抢红包，无视好友消息撤回，修改微信运动步数，朋友圈小视频长按时支持一键转发、保存本地、复制链接\n具体功能参数说明：(在微信通讯录中给自己发以下数字序号后的简短文字)\n0.使用说明:显示本版本的一些功能说明\n1.打开红包插件:开启抢红包插件,默认抢自己的\n2.关闭红包插件:关闭抢红包插件\n3.关闭抢自己红包:自己发的红包不自动抢,恢复请参照1\n4.关闭抢群红包:不抢群里发的红包,恢复请参照1\n5.修改微信步数#:#后面跟相应的数字(Tips:必须为数字，否则可能会引起微信闪退,数字尽量不要太夸张)\n6.恢复微信步数:恢复微信步数\n7.抢红包延迟#:#后面跟数字，设置抢红包的延迟(太快可能会被微信察觉,默认设置的是0.9)===注意事项===\n关于抢红包：请勿把微信进程杀掉，否则会抢不到（home键后台即可），网络因素会导致抢红包延迟；朋友圈小视频一键转发等功能需先加载完成此小视频后再长按;";
                isFind=YES;
            }
            if (isFind) {
                //保存抢红包设置
                SAVESETTINGS(HBPluginTypeKey, [NSNumber numberWithInt:HBPluginType], HBPluginSettingFile)
                SAVESETTINGS(HBPluginDelayKey, [NSNumber numberWithFloat:HBPluginDelay], HBPluginDelaySettingFile)
                //修改消息
                object_setIvar(arg2, nsContentIvar, m_nsContent);
            }
        }
    }
//    //开启@所有人功能
//    if ([m_nsContent hasPrefix:@"!all:"] && [m_nsToUsr rangeOfString:@"@chatroom"].location != NSNotFound && !m_nsMsgSource && [m_nsFromUsr rangeOfString:@"@chatroom"].location == NSNotFound) {
//        //微信的服务中心
//        Method methodMMServiceCenter = class_getClassMethod(objc_getClass("MMServiceCenter"), @selector(defaultCenter));
//        IMP impMMSC = method_getImplementation(methodMMServiceCenter);
//        id MMServiceCenter = impMMSC(objc_getClass("MMServiceCenter"), @selector(defaultCenter));
//        //通讯录管理器,获取自己的微信账号，用来判断是否是自己发送的
//        id contactManager = ((id (*)(id, SEL, Class))objc_msgSend)(MMServiceCenter, @selector(getService:),objc_getClass("CContactMgr"));
//        Method methodGetSelfContact = class_getInstanceMethod(objc_getClass("CContactMgr"), @selector(getSelfContact));
//        IMP impGS = method_getImplementation(methodGetSelfContact);
//        id selfContact = impGS(contactManager, @selector(getSelfContact));
//        Ivar nsUsrNameIvar = class_getInstanceVariable([selfContact class], "m_nsUsrName");
//        id m_nsUsrName = object_getIvar(selfContact, nsUsrNameIvar);
//        //判断是否是自己发送的消息
//        if ([m_nsFromUsr isEqualToString:m_nsUsrName] ) {
//            //            先获取除了我之外的所有群成员
//            id memberList = [objc_getClass("CContact") performSelector:@selector(getChatRoomMemberWithoutMyself:) withObject:m_nsToUsr];
//            //把获取到的每个member的name进行拼接
//            NSMutableString *allMemberNames=[NSMutableString stringWithFormat:@""];
//            for (id member in memberList) {
//                NSString *name=[member valueForKey:@"m_nsUsrName"];
//                [allMemberNames appendString:[NSString stringWithFormat:@"%@,",name]];
//            }
//            //去除约定好的前缀
//            NSString *newContent=[m_nsContent substringFromIndex:5];
//            object_setIvar(arg2, nsContentIvar, newContent);
//            //设置要@的人
//            object_setIvar(arg2, nsMsgSource, [NSString stringWithFormat:@"<msgsource><atuserlist>%@</atuserlist></msgsource>",[allMemberNames substringToIndex:allMemberNames.length-1]]);
//        }
//    }
    CHSuper2(CMessageMgr, AddMsg, arg1, MsgWrap, arg2);
}

CHMethod2(void, CMessageMgr, AsyncOnAddMsg, id, arg1, MsgWrap, id, arg2) {
    CHSuper2(CMessageMgr, AsyncOnAddMsg, arg1, MsgWrap, arg2);
    Ivar uiMessageTypeIvar = class_getInstanceVariable(objc_getClass("CMessageWrap"), "m_uiMessageType");
    ptrdiff_t offset = ivar_getOffset(uiMessageTypeIvar);
    unsigned char *stuffBytes = (unsigned char *)(__bridge void *)arg2;
    NSUInteger m_uiMessageType = * ((NSUInteger *)(stuffBytes + offset));
    
    Ivar nsFromUsrIvar = class_getInstanceVariable(objc_getClass("CMessageWrap"), "m_nsFromUsr");
    id m_nsFromUsr = object_getIvar(arg2, nsFromUsrIvar);
    Ivar nsToUsrIvar = class_getInstanceVariable(objc_getClass("CMessageWrap"), "m_nsToUsr");
    id m_nsToUsr = object_getIvar(arg2, nsToUsrIvar);
    
    Ivar nsContentIvar = class_getInstanceVariable(objc_getClass("CMessageWrap"), "m_nsContent");
    id m_nsContent = object_getIvar(arg2, nsContentIvar);
    switch(m_uiMessageType) {
        case 49://红包消息
        {
            NSString *docDir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
            NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:[docDir stringByAppendingPathComponent:HBPluginSettingFile]];
            if (dict){
                HBPluginType = ((NSNumber *)dict[HBPluginTypeKey]).intValue;
            }
            //微信的服务中心
            Method methodMMServiceCenter = class_getClassMethod(objc_getClass("MMServiceCenter"), @selector(defaultCenter));
            IMP impMMSC = method_getImplementation(methodMMServiceCenter);
            id MMServiceCenter = impMMSC(objc_getClass("MMServiceCenter"), @selector(defaultCenter));
            //红包控制器
            id logicMgr = ((id (*)(id, SEL, Class))objc_msgSend)(MMServiceCenter, @selector(getService:),objc_getClass("WCRedEnvelopesLogicMgr"));
            //通讯录管理器
            id contactManager = ((id (*)(id, SEL, Class))objc_msgSend)(MMServiceCenter, @selector(getService:),objc_getClass("CContactMgr"));
            
            Method methodGetSelfContact = class_getInstanceMethod(objc_getClass("CContactMgr"), @selector(getSelfContact));
            IMP impGS = method_getImplementation(methodGetSelfContact);
            id selfContact = impGS(contactManager, @selector(getSelfContact));
            
            Ivar nsUsrNameIvar = class_getInstanceVariable([selfContact class], "m_nsUsrName");
            id m_nsUsrName = object_getIvar(selfContact, nsUsrNameIvar);
            BOOL isMesasgeFromMe = NO;
            BOOL isChatroom = NO;
            if ([m_nsFromUsr isEqualToString:m_nsUsrName]) {
                isMesasgeFromMe = YES;
            }
            if ([m_nsFromUsr rangeOfString:@"@chatroom"].location != NSNotFound || [m_nsToUsr rangeOfString:@"@chatroom"].location != NSNotFound)
            {
                isChatroom = YES;
            }
            if (isMesasgeFromMe && kCloseRedEnvPluginForMyself == HBPluginType && isChatroom) {
                //不抢自己的红包
                break;
            }
            else if(kCloseRedEnvPluginForMyselfFromChatroom == HBPluginType && isChatroom)
            {
                //不抢群里的红包
                break;
            }
            
            if ([m_nsContent rangeOfString:@"wxpay://"].location != NSNotFound)
            {
                NSString *nativeUrl = m_nsContent;
                NSRange rangeStart = [m_nsContent rangeOfString:@"wxpay://c2cbizmessagehandler/hongbao"];
                if (rangeStart.location != NSNotFound)
                {
                    NSUInteger locationStart = rangeStart.location;
                    nativeUrl = [nativeUrl substringFromIndex:locationStart];
                }
                
                NSRange rangeEnd = [nativeUrl rangeOfString:@"]]"];
                if (rangeEnd.location != NSNotFound)
                {
                    NSUInteger locationEnd = rangeEnd.location;
                    nativeUrl = [nativeUrl substringToIndex:locationEnd];
                }
                
                NSString *naUrl = [nativeUrl substringFromIndex:[@"wxpay://c2cbizmessagehandler/hongbao/receivehongbao?" length]];
                
                NSArray *parameterPairs =[naUrl componentsSeparatedByString:@"&"];
                
                NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithCapacity:[parameterPairs count]];
                for (NSString *currentPair in parameterPairs) {
                    NSRange range = [currentPair rangeOfString:@"="];
                    if(range.location == NSNotFound)
                        continue;
                    NSString *key = [currentPair substringToIndex:range.location];
                    NSString *value =[currentPair substringFromIndex:range.location + 1];
                    [parameters setObject:value forKey:key];
                }
                
                //红包参数
                NSMutableDictionary *params = [@{} mutableCopy];
                
                [params setObject:parameters[@"msgtype"]?:@"null" forKey:@"msgType"];
                [params setObject:parameters[@"sendid"]?:@"null" forKey:@"sendId"];
                [params setObject:parameters[@"channelid"]?:@"null" forKey:@"channelId"];
                
                id getContactDisplayName = objc_msgSend(selfContact, @selector(getContactDisplayName));
                id m_nsHeadImgUrl = objc_msgSend(selfContact, @selector(m_nsHeadImgUrl));
                
                [params setObject:getContactDisplayName forKey:@"nickName"];
                [params setObject:m_nsHeadImgUrl forKey:@"headImg"];
                [params setObject:[NSString stringWithFormat:@"%@", nativeUrl]?:@"null" forKey:@"nativeUrl"];
                [params setObject:m_nsFromUsr?:@"null" forKey:@"sessionUserName"];
                
                if (kCloseRedEnvPlugin != HBPluginType) {
                    //自动抢红包
                    NSString *docDir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
                    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:[docDir stringByAppendingPathComponent:HBPluginDelaySettingFile]];
                    if (dict){
                        HBPluginDelay = ((NSNumber *)dict[HBPluginDelayKey]).floatValue;
                    }
                    if (HBPluginDelay<0) {
                        HBPluginDelay=0;
                    }
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(HBPluginDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        ((void (*)(id, SEL, NSMutableDictionary*))objc_msgSend)(logicMgr, @selector(OpenRedEnvelopesRequest:), params);
                    });
                }
                return;
            }
            break;
        }
        default:
            break;
    }
}

//所有被hook的类和函数放在这里的构造函数中
CHConstructor
{
    @autoreleasepool
    {
        CHLoadLateClass(WCContentItemViewTemplateNewSight);
        CHHook(0, WCContentItemViewTemplateNewSight, onLongTouch);// register hook
        
        CHLoadLateClass(SightMomentEditViewController);
        CHHook(0, SightMomentEditViewController, popSelf);
        
        CHLoadLateClass(WCDeviceStepObject);
        CHHook0(WCDeviceStepObject, m7StepCount);
        
        CHLoadLateClass(CMessageMgr);
        CHHook2(CMessageMgr, AsyncOnAddMsg, MsgWrap);
        CHHook2(CMessageMgr, AddMsg, MsgWrap);
        CHHook1(CMessageMgr, onRevokeMsg);
    }
}
