import QtQuick
import Quickshell
import qs.Modules.ControlCenter
import qs.Common
import qs.Services
import qs.Widgets.common

AccountProfileHeader {
    id: root

    signal imageSelectionRequested(bool forAvatar)

    property string screenName: ""
    coverHeight: Math.round(width / 2.5)
    profileAreaHeight: 112
    avatarSize: 96
    wallpaperPath: bannerEditor.source
    colorWallpaper: WallpaperService.isColorSource(wallpaperPath)
    avatarUrl: AvatarService.avatarUrl
    fallbackAvatarUrl: Paths.fileUrl(Paths.defaultAvatar)
    accountIdentity: SystemIdentityService.accountIdentity
    distroId: SystemIdentityService.distroId
    distroName: SystemIdentityService.distroName
    uptimeText: SystemIdentityService.uptimeText
    showNetworkStatus: false
    surfaceColor: BlurService.opaqueBackgroundColor(Appearance.m3colors.m3surfaceContainerHigh)

    ProfileBannerEditor {
        id: bannerEditor
        parentModal: root.QsWindow.window
    }
    onBannerFileActivated: root.imageSelectionRequested(false)
    onBannerColorActivated: bannerEditor.chooseColor()
    onBannerCleared: bannerEditor.clear()
    Connections {
        target: WidgetState
        function onDashboardSidebarOpenChanged() {
            if (!WidgetState.dashboardSidebarOpen) {
                bannerEditor.close();
            }
        }
    }
    onAvatarActivated: root.imageSelectionRequested(true)
}
