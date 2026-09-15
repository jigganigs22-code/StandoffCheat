#import "menu.h"
#import "cheat_data.h"

UIWindow* g_menuWindow = nil;
CheatMenuController* g_menuController = nil;

static UIColor* ThemeColor(int r, int g, int b) {
    return [UIColor colorWithRed:r/255.0 green:g/255.0 blue:b/255.0 alpha:1.0];
}

@interface CheatMenuRootView : UIView
@property (nonatomic, assign) CheatMenuController* host;
@end

@interface CheatMenuController () <UIGestureRecognizerDelegate>
@property (nonatomic, assign) BOOL layoutDone;
@end

@implementation CheatMenuRootView

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent*)event {
    CheatMenuController* c = self.host;
    if (!c) return NO;
    if (c.toggleBtn && CGRectContainsPoint(c.toggleBtn.frame, point)) return YES;
    if (c.menuPanel && !c.menuPanel.hidden && CGRectContainsPoint(c.menuPanel.frame, point)) return YES;
    return NO;
}

@end

@implementation CheatMenuController

- (void)loadView {
    CheatMenuRootView* root = [[CheatMenuRootView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    root.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    root.host = self;
    self.view = root;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];
    self.view.userInteractionEnabled = YES;

    CGFloat btnSize = 48;
    self.toggleBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.toggleBtn.frame = CGRectMake(self.view.bounds.size.width - btnSize - 14, 120, btnSize, btnSize);
    self.toggleBtn.backgroundColor = ThemeColor(30, 160, 90);
    self.toggleBtn.layer.cornerRadius = btnSize / 2;
    self.toggleBtn.layer.shadowColor = [UIColor blackColor].CGColor;
    self.toggleBtn.layer.shadowOpacity = 0.7;
    self.toggleBtn.layer.shadowRadius = 4;
    self.toggleBtn.layer.shadowOffset = CGSizeMake(0, 2);
    [self.toggleBtn setTitle:@"⚙" forState:UIControlStateNormal];
    self.toggleBtn.titleLabel.font = [UIFont boldSystemFontOfSize:22];
    self.toggleBtn.accessibilityIdentifier = @"cheat_toggle";
    [self.toggleBtn addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];

    UIPanGestureRecognizer* pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panMenu:)];
    [self.toggleBtn addGestureRecognizer:pan];

    [self.view addSubview:self.toggleBtn];

    self.menuPanel = [[UIView alloc] initWithFrame:CGRectMake(10, 50, 250, 0)];
    self.menuPanel.backgroundColor = [ThemeColor(18, 20, 28) colorWithAlphaComponent:0.95];
    self.menuPanel.layer.cornerRadius = 12;
    self.menuPanel.layer.borderColor = ThemeColor(30, 160, 90).CGColor;
    self.menuPanel.layer.borderWidth = 1.5;
    self.menuPanel.clipsToBounds = YES;
    self.menuPanel.hidden = YES;
    [self.view addSubview:self.menuPanel];

    UIPanGestureRecognizer* panelPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panMenu:)];
    panelPan.delegate = self;
    [self.menuPanel addGestureRecognizer:panelPan];

    self.expanded = NO;
    [self rebuildMenu];
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer*)gr {
    if (gr.view == self.menuPanel) {
        CGPoint p = [gr locationInView:self.menuPanel];
        for (UIView* sub in self.menuPanel.subviews) {
            if ([sub isKindOfClass:[UIControl class]] && CGRectContainsPoint(sub.frame, p)) {
                return NO;
            }
        }
    }
    return YES;
}

- (void)panMenu:(UIPanGestureRecognizer*)pan {
    CGRect b = self.view.bounds;
    CGPoint t = [pan translationInView:self.view];

    CGRect tf = self.toggleBtn.frame;
    CGRect pf = self.menuPanel.frame;

    tf.origin.x += t.x;
    tf.origin.y += t.y;
    tf.origin.x = MAX(10, MIN(tf.origin.x, b.size.width - tf.size.width - 10));
    tf.origin.y = MAX(30, MIN(tf.origin.y, b.size.height - tf.size.height - 30));

    pf.origin.x += t.x;
    pf.origin.y += t.y;
    pf.origin.x = MAX(8, MIN(pf.origin.x, b.size.width - pf.size.width - 8));
    pf.origin.y = MAX(20, MIN(pf.origin.y, b.size.height - pf.size.height - 20));

    self.toggleBtn.frame = tf;
    self.menuPanel.frame = pf;
    [pan setTranslation:CGPointZero inView:self.view];
}

- (void)toggleMenu {
    self.expanded = !self.expanded;
    self.menuPanel.hidden = !self.expanded;
    g_config.menuOpen = self.expanded;
}

- (void)addSection:(NSString*)title y:(CGFloat*)y {
    UILabel* label = [[UILabel alloc] initWithFrame:CGRectMake(14, *y, 222, 24)];
    label.text = title;
    label.textColor = ThemeColor(90, 210, 130);
    label.font = [UIFont boldSystemFontOfSize:14];
    [self.menuPanel addSubview:label];
    *y += 26;
}

- (void)addToggle:(NSString*)label target:(BOOL*)target y:(CGFloat*)y renderTag:(NSInteger)tag {
    CGFloat rowW = 222, rowH = 30;

    UILabel* txt = [[UILabel alloc] initWithFrame:CGRectMake(16, *y + 5, 150, 20)];
    txt.text = label;
    txt.textColor = [UIColor whiteColor];
    txt.font = [UIFont systemFontOfSize:13];
    [self.menuPanel addSubview:txt];

    UISwitch* sw = [[UISwitch alloc] initWithFrame:CGRectMake(172, *y, 48, rowH)];
    sw.on = *target;
    sw.onTintColor = ThemeColor(30, 160, 90);
    sw.tag = tag;
    [sw addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    [self.menuPanel addSubview:sw];

    *y += rowH;
}

- (void)addSlider:(NSString*)label fmt:(NSString*)fmt value:(float)val min:(float)min max:(float)max target:(float*)target y:(CGFloat*)y tag:(NSInteger)tag {
    CGFloat rowW = 222, rowH = 44;

    UILabel* title = [[UILabel alloc] initWithFrame:CGRectMake(16, *y, 150, 20)];
    title.text = label;
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont systemFontOfSize:13];
    [self.menuPanel addSubview:title];

    UILabel* valueLabel = [[UILabel alloc] initWithFrame:CGRectMake(150, *y, 88, 20)];
    valueLabel.textAlignment = NSTextAlignmentRight;
    valueLabel.textColor = ThemeColor(120, 220, 160);
    valueLabel.font = [UIFont systemFontOfSize:12];
    valueLabel.tag = tag + 1000;
    valueLabel.text = [NSString stringWithFormat:fmt, val];
    [self.menuPanel addSubview:valueLabel];

    UISlider* slider = [[UISlider alloc] initWithFrame:CGRectMake(16, *y + 22, 218, 22)];
    slider.minimumValue = min;
    slider.maximumValue = max;
    slider.value = val;
    slider.minimumTrackTintColor = ThemeColor(30, 160, 90);
    slider.tag = tag;
    [slider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
    [self.menuPanel addSubview:slider];

    *y += rowH;
}

- (void)switchChanged:(UISwitch*)sw {
    switch (sw.tag) {
        case 1: g_config.espEnabled = sw.on; break;
        case 2: g_config.espBoxes = sw.on; break;
        case 3: g_config.espHealthBars = sw.on; break;
        case 4: g_config.espNames = sw.on; break;
        case 5: g_config.espSnaplines = sw.on; break;
        case 6: g_config.espDistance = sw.on; break;
        case 7: g_config.espTeamColor = sw.on; break;
        case 8: g_config.aimbotEnabled = sw.on; break;
        case 9: g_config.aimbotOnShoot = sw.on; break;
        case 10: g_config.aimbotShowFov = sw.on; break;
        case 11: g_config.recoilEnabled = sw.on; break;
        default: break;
    }
}

- (void)sliderChanged:(UISlider*)slider {
    float v = slider.value;
    switch (slider.tag) {
        case 20: {
            g_config.aimbotFov = v;
            UILabel* lbl = (UILabel*)[self.menuPanel viewWithTag:1020];
            lbl.text = [NSString stringWithFormat:@"%.0f°", v];
            break;
        }
        case 21: {
            g_config.aimbotSmooth = v;
            UILabel* lbl = (UILabel*)[self.menuPanel viewWithTag:1021];
            lbl.text = [NSString stringWithFormat:@"%.0f", v];
            break;
        }
        default: break;
    }
}

- (void)rebuildMenu {
    for (UIView* v in self.menuPanel.subviews) [v removeFromSuperview];

    CGFloat y = 10;

    UILabel* title = [[UILabel alloc] initWithFrame:CGRectMake(14, y, 220, 26)];
    title.text = @"StandoffCheat v1.0";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont boldSystemFontOfSize:16];
    [self.menuPanel addSubview:title];
    y += 24;

    [self addSection:@"ESP" y:&y];
    [self addToggle:@"ESP Enabled" target:&g_config.espEnabled y:&y renderTag:1];
    [self addToggle:@"Boxes" target:&g_config.espBoxes y:&y renderTag:2];
    [self addToggle:@"Health Bars" target:&g_config.espHealthBars y:&y renderTag:3];
    [self addToggle:@"Names" target:&g_config.espNames y:&y renderTag:4];
    [self addToggle:@"Snaplines" target:&g_config.espSnaplines y:&y renderTag:5];
    [self addToggle:@"Distance" target:&g_config.espDistance y:&y renderTag:6];
    [self addToggle:@"Team Colors" target:&g_config.espTeamColor y:&y renderTag:7];

    [self addSection:@"Aimbot" y:&y];
    [self addToggle:@"Aimbot" target:&g_config.aimbotEnabled y:&y renderTag:8];
    [self addToggle:@"Shoot Only" target:&g_config.aimbotOnShoot y:&y renderTag:9];
    [self addSlider:@"FOV" fmt:@"%.0f°" value:g_config.aimbotFov min:10 max:200 target:&g_config.aimbotFov y:&y tag:20];
    [self addSlider:@"Smooth" fmt:@"%.0f" value:g_config.aimbotSmooth min:1 max:20 target:&g_config.aimbotSmooth y:&y tag:21];
    [self addToggle:@"Show FOV Ring" target:&g_config.aimbotShowFov y:&y renderTag:10];

    [self addSection:@"Recoil" y:&y];
    [self addToggle:@"No Recoil" target:&g_config.recoilEnabled y:&y renderTag:11];

    y += 6;
    UIButton* closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    closeBtn.frame = CGRectMake(16, y, 218, 32);
    closeBtn.backgroundColor = ThemeColor(200, 50, 50);
    closeBtn.layer.cornerRadius = 8;
    [closeBtn setTitle:@"Close" forState:UIControlStateNormal];
    [closeBtn.titleLabel setFont:[UIFont boldSystemFontOfSize:15]];
    [closeBtn addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];
    [self.menuPanel addSubview:closeBtn];
    y += 46;

    CGRect panelFrame = self.menuPanel.frame;
    panelFrame.size.height = y;
    panelFrame.size.width = 250;
    self.menuPanel.frame = panelFrame;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if (self.layoutDone) return;
    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;
    self.toggleBtn.frame = CGRectMake(w - 62, h * 0.18f, 48, 48);
    self.menuPanel.frame = CGRectMake(10, 50, 250, self.menuPanel.bounds.size.height);
    self.layoutDone = YES;
}
@end

void SetupMenuWindow() {
    if (g_menuWindow) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (g_menuWindow) return;
        g_menuWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        g_menuWindow.windowLevel = UIWindowLevelStatusBar + 50;
        g_menuWindow.userInteractionEnabled = YES;
        g_menuWindow.backgroundColor = [UIColor clearColor];
        g_menuController = [[CheatMenuController alloc] init];
        g_menuWindow.rootViewController = g_menuController;
        g_menuWindow.hidden = NO;
    });
}

void ToggleMenu() {
    if (!g_menuController) { SetupMenuWindow(); return; }
    dispatch_async(dispatch_get_main_queue(), ^{
        [g_menuController toggleMenu];
    });
}

void ShowMenu() {
    if (!g_menuWindow) SetupMenuWindow();
}

bool MenuVisible() {
    return g_config.menuOpen;
}