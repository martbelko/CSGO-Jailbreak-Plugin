#if defined HUD_INC
 #endinput
#endif
#define HUD_INC

native void OnPointsChanged(int client, int numPoints);
native void OnSkinChanged(int client, const char[] skinName);
native void OnWardenChanged(int warden);
native void OnPlayerGetItem(int client, const char[] text);
