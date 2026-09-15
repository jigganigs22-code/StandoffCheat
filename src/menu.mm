#import "menu.h"
#import "cheat_data.h"

UIWindow* g_menuWindow = nil;
CheatMenuController* g_menuController = nil;

static UIColor* ThemeColor(int r, int g, int b) {
    return [UIColor colorWithRed:r/255.0 green:g/255.0 blue:b/255.0 alpha:1.0];
}

static const CGFloat kBarW = 170;
static const CGFloat kBarH = 40;
static const CGFloat kPanelW = 400;

@interface CheatMenuController () <UIGestureRecognizerDelegate>
@property (nonatomic, assign) CGPoint anchor;
@property (nonatomic, assign) CGFloat panelHeight;
@end

@implementation CheatMenuController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];
    self.view.userInteractionEnabled = YES;

    CGRect screen = [UIScreen mainScreen].bounds;
    self.anchor = CGPointMake(screen.size.width - kBarW - 14, 110);

    UIButton* gear = [UIButton buttonWithType:UIButtonTypeCustom];
    gear.frame = CGRectMake(8, 4, 32, 32);
    gear.backgroundColor = ThemeColor(30, 160, 90);
    gear.layer.cornerRadius = 16;
    gear.layer.shadowColor = [UIColor blackColor].CGColor;
    gear.layer.shadowOpacity = 0.7;
    gear.layer.shadowRadius = 3;
    gear.layer.shadowOffset = CGSizeMake(0, 2);
    [gear setTitle:@"⚙" forState:UIControlStateNormal];
    gear.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [gear addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:gear];
    self.toggleBtn = gear;

    UILabel* title = [[UILabel alloc] initWithFrame:CGRectMake(48, 8, 116, 22)];
    title.text = @"StandoffCheat";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont boldSystemFontOfSize:13];
    [self.view addSubview:title];

    UIView* headerBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kBarW, kBarH)];
    headerBar.backgroundColor = [ThemeColor(18, 20, 28) colorWithAlphaComponent:0.92];
    headerBar.layer.cornerRadius = 10;
    headerBar.layer.borderColor = ThemeColor(30, 160, 90).CGColor;
    headerBar.layer.borderWidth = 1.2;
    headerBar.tag = 777;
    [self.view addSubview:headerBar];

    UIPanGestureRecognizer* barPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragMenu:)];
    [headerBar addGestureRecognizer:barPan];

    self.menuPanel = [[UIView alloc] initWithFrame:CGRectMake(0, kBarH, kPanelW, 0)];
    self.menuPanel.backgroundColor = [ThemeColor(14, 16, 22) colorWithAlphaComponent:0.96];
    self.menuPanel.layer.cornerRadius = 10;
    self.menuPanel.layer.borderColor = ThemeColor(30, 160, 90).CGColor;
    self.menuPanel.layer.borderWidth = 1.2;
    self.menuPanel.clipsToBounds = YES;
    self.menuPanel.hidden = YES;
    [self.view addSubview:self.menuPanel];

    UIPanGestureRecognizer* panelPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragMenu:)];
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

- (void)dragMenu:(UIPanGestureRecognizer*)gr {
    CGPoint t = [gr translationInView:self.view];
    CGRect f = g_menuWindow.frame;
    self.anchor.x += t.x;
    self.anchor.y += t.y;
    [self clampAnchorToScreen];
    f.origin = self.anchor;
    g_menuWindow.frame = f;
    [gr setTranslation:CGPointZero inView:self.view];
}

- (void)clampAnchorToScreen {
    CGRect screen = [UIScreen mainScreen].bounds;
    CGRect f = g_menuWindow.frame;
    self.anchor.x = MAX(6, MIN(self.anchor.x, screen.size.width - f.size.width - 6));
    self.anchor.y = MAX(24, MIN(self.anchor.y, screen.size.height - f.size.height - 6));
}

- (void)toggleMenu {
    self.expanded = !self.expanded;
    self.menuPanel.hidden = !self.expanded;
    if (self.expanded) [self.menuPanel.superview bringSubviewToFront:self.menuPanel];
    g_config.menuOpen = self.expanded;
    [self updateWindowFrame];
}

- (void)updateWindowFrame {
    if (!g_menuWindow) return;
    CGRect f = g_menuWindow.frame;
    if (self.expanded) {
        f.size = CGSizeMake(kPanelW, kBarH + self.panelHeight);
    } else {
        f.size = CGSizeMake(kBarW, kBarH);
    }
    f.origin = self.anchor;
    g_menuWindow.frame = f;
    [self clampAnchorToScreen];
    f.origin = self.anchor;
    g_menuWindow.frame = f;
    [self.view setNeedsLayout];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGRect b = self.view.bounds;
    UIView* bar = [self.view viewWithTag:777];
    if (bar) bar.frame = CGRectMake(0, 0, b.size.width, kBarH);
    self.menuPanel.frame = CGRectMake(0, kBarH, b.size.width, b.size.height - kBarH);
    self.toggleBtn.frame = CGRectMake(8, 4, 32, 32);
}

#pragma mark - UI building

- (void)addToggleCol:(CGFloat)colX label:(NSString*)label tag:(NSInteger)tag y:(CGFloat)y {
    CGFloat colW = (kPanelW - 26) / 2.0;
    UILabel* txt = [[UILabel alloc] initWithFrame:CGRectMake(colX + 6, y + 2, colW - 62, 18)];
    txt.text = label;
    txt.textColor = [UIColor whiteColor];
    txt.font = [UIFont systemFontOfSize:12];
    [self.menuPanel addSubview:txt];

    UISwitch* sw = [[UISwitch alloc] initWithFrame:CGRectMake(colX + colW - 50, y - 1, 48, 20)];
    sw.onTintColor = ThemeColor(30, 160, 90);
    sw.transform = CGAffineTransformMakeScale(0.62, 0.62);
    sw.tag = tag;
    switch (tag) {
        case 1: sw.on = g_config.espEnabled; break;
        case 2: sw.on = g_config.espBoxes; break;
        case 3: sw.on = g_config.espHealthBars; break;
        case 4: sw.on = g_config.espNames; break;
        case 5: sw.on = g_config.espSnaplines; break;
        case 6: sw.on = g_config.espDistance; break;
        case 7: sw.on = g_config.espTeamColor; break;
        case 8: sw.on = g_config.aimbotEnabled; break;
        case 9: sw.on = g_config.aimbotOnShoot; break;
        case 10: sw.on = g_config.aimbotShowFov; break;
        case 11: sw.on = g_config.recoilEnabled; break;
        default: break;
    }
    [sw addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    [self.menuPanel addSubview:sw];
}

- (void)addSliderCol:(CGFloat)colX label:(NSString*)label fmt:(NSString*)fmt tag:(NSInteger)tag y:(CGFloat)y {
    CGFloat colW = (kPanelW - 26) / 2.0;
    UILabel* t = [[UILabel alloc] initWithFrame:CGRectMake(colX + 6, y, colW - 60, 16)];
    t.text = label;
    t.textColor = [UIColor whiteColor];
    t.font = [UIFont systemFontOfSize:11];
    [self.menuPanel addSubview:t];

    UILabel* v = [[UILabel alloc] initWithFrame:CGRectMake(colX + colW - 58, y, 52, 16)];
    v.textAlignment = NSTextAlignmentRight;
    v.textColor = ThemeColor(120, 220, 160);
    v.font = [UIFont systemFontOfSize:11];
    v.tag = tag + 1000;
    v.text = [NSString stringWithFormat:fmt, tag == 20 ? g_config.aimbotFov : g_config.aimbotSmooth];
    [self.menuPanel addSubview:v];

    UISlider* sl = [[UISlider alloc] initWithFrame:CGRectMake(colX + 6, y + 16, colW - 12, 16)];
    sl.minimumValue = (tag == 20) ? 10 : 1;
    sl.maximumValue = (tag == 20) ? 200 : 20;
    sl.value = (tag == 20) ? g_config.aimbotFov : g_config.aimbotSmooth;
    sl.minimumTrackTintColor = ThemeColor(30, 160, 90);
    sl.tag = tag;
    [sl addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
    [self.menuPanel addSubview:sl];
}

- (void)addSection:(NSString*)title y:(CGFloat*)y {
    UILabel* label = [[UILabel alloc] initWithFrame:CGRectMake(12, *y + 1, 376, 16)];
    label.text = title;
    label.textColor = ThemeColor(90, 210, 130);
    label.font = [UIFont boldSystemFontOfSize:12];
    [self.menuPanel addSubview:label];
    *y += 18;
}

- (void)rebuildMenu {
    for (UIView* v in self.menuPanel.subviews) [v removeFromSuperview];

    CGFloat y = 6;
    CGFloat colW = (kPanelW - 26) / 2.0;
    CGFloat c1 = 10, c2 = 16 + colW;

    [self addSection:@"ESP" y:&y];

    NSArray* espToggles = @[ @1, @2, @3, @4, @5, @6, @7 ];
    NSArray* espLabels = @[ @"ESP Enabled", @"Boxes", @"Health Bars", @"Names", @"Snaplines", @"Distance", @"Team Colors" ];
    for (NSUInteger i = 0; i < espToggles.count; i++) {
        CGFloat colX = (i % 2 == 0) ? c1 : c2;
        [self addToggleCol:colX label:espLabels[i] tag:[espToggles[i] integerValue] y:y];
        if (i % 2 == 1) y += 22;
    }
    if (espToggles.count % 2 == 1) y += 22;

    [self addSection:@"Aimbot" y:&y];

    [self addToggleCol:c1 label:@"Aimbot" tag:8 y:y];
    [self addToggleCol:c2 label:@"Shoot Only" tag:9 y:y];
    y += 22;

    [self addSliderCol:c1 label:@"FOV" fmt:@"%.0f°" tag:20 y:y];
    [self addSliderCol:c2 label:@"Smooth" fmt:@"%.0f" tag:21 y:y];
    y += 36;

    [self addToggleCol:c1 label:@"Show FOV Ring" tag:10 y:y];
    y += 22;

    [self addSection:@"Recoil" y:&y];
    [self addToggleCol:c1 label:@"No Recoil" tag:11 y:y];
    y += 22;

    y += 2;

    UIButton* closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    closeBtn.frame = CGRectMake(10, y, kPanelW - 20, 26);
    closeBtn.backgroundColor = ThemeColor(200, 50, 50);
    closeBtn.layer.cornerRadius = 6;
    [closeBtn setTitle:@"Close" forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    [closeBtn addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];
    [self.menuPanel addSubview:closeBtn];
    y += 32;

    self.panelHeight = y + 4;
    [self updateWindowFrame];
}

#pragma mark - Control events

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
    if (slider.tag == 20) {
        g_config.aimbotFov = v;
        UILabel* lbl = (UILabel*)[self.menuPanel viewWithTag:1020];
        lbl.text = [NSString stringWithFormat:@"%.0f°", v];
    } else if (slider.tag == 21) {
        g_config.aimbotSmooth = v;
        UILabel* lbl = (UILabel*)[self.menuPanel viewWithTag:1021];
        lbl.text = [NSString stringWithFormat:@"%.0f", v];
    }
}

@end

#pragma mark - C API

void SetupMenuWindow() {
    if (g_menuWindow) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (g_menuWindow) return;
        CGRect screen = [UIScreen mainScreen].bounds;
        g_menuWindow = [[UIWindow alloc] initWithFrame:CGRectMake(screen.size.width - kBarW - 14, 110, kBarW, kBarH)];
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