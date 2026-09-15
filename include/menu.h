#pragma once
#import <UIKit/UIKit.h>

@class CheatMenuController;

@interface CheatMenuController : UIViewController
@property (nonatomic, strong) UIView* menuPanel;
@property (nonatomic, strong) UIButton* toggleBtn;
@property (nonatomic, assign) BOOL expanded;
- (void)toggleMenu;
- (void)rebuildMenu;
- (void)addSection:(NSString*)title y:(CGFloat*)y NS_SWIFT_NAME(addSection(y:));
@end

extern CheatMenuController* g_menuController;
extern UIWindow* g_menuWindow;

void ShowMenu();
void ToggleMenu();
bool MenuVisible();
void SetupMenuWindow();