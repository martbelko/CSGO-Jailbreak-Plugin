#if defined JB_HUD_INC
 #endinput
#endif
#define JB_HUD_INC

native void OnPointsChanged(int client, int numPoints);
native void OnSkinChanged(int client, const char[] skinName);
native void OnWardenChanged(int warden);