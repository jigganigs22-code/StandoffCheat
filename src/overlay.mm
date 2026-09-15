#import "overlay.h"
#import <QuartzCore/QuartzCore.h>

extern void CheatUpdateMainThread(void);

static UIWindow* g_overlayWindow = nil;
static ESPOverlayView* g_overlayView = nil;
static CADisplayLink* g_displayLink = nil;
static ESP* g_espPtr = nullptr;

@implementation ESPOverlayView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.opaque = NO;
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO;
    }
    return self;
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent*)event {
    return NO;
}

- (void)drawRect:(CGRect)rect {
    if (!g_espPtr || !g_config.initialized) return;
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) return;

    CGContextSetAllowsAntialiasing(ctx, true);
    CGContextSetShouldAntialias(ctx, true);

    CGFloat scale = [UIScreen mainScreen].scale;
    CGFloat width = self.bounds.size.width * scale;
    CGFloat height = self.bounds.size.height * scale;

    g_espPtr->Render(ctx, width, height);
}

- (void)displayLinkTick:(CADisplayLink*)link {
    CheatUpdateMainThread();
    if (g_espPtr && g_config.initialized) [self setNeedsDisplay];
}

@end

void SetupOverlayWindow() {
    if (g_overlayWindow) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (g_overlayWindow) return;

        CGRect bounds = [UIScreen mainScreen].bounds;
        g_overlayWindow = [[UIWindow alloc] initWithFrame:bounds];
        g_overlayWindow.windowLevel = UIWindowLevelStatusBar + 100;
        g_overlayWindow.userInteractionEnabled = NO;
        g_overlayWindow.backgroundColor = [UIColor clearColor];
        g_overlayWindow.hidden = NO;

        g_overlayView = [[ESPOverlayView alloc] initWithFrame:bounds];
        g_overlayView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [g_overlayWindow addSubview:g_overlayView];

        g_espPtr = (ESP*)GetESP();

        g_displayLink = [CADisplayLink displayLinkWithTarget:g_overlayView selector:@selector(displayLinkTick:)];
        [g_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    });
}