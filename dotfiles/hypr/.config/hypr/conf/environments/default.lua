hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")

-- Only expose the Intel Vulkan driver to the session. The Vulkan loader
-- otherwise loads every driver to enumerate devices, and loading NVIDIA's
-- opens the dGPU and keeps it awake (swaync, GTK4 apps, voxtype did).
-- Apps that pick the "discrete" GPU (libplacebo/mpv, GTK4) can't land on
-- it either. Run something on NVIDIA with: use-gpu <command>
-- (matrix/scripts/matrix-use-gpu). MESA_VK_DEVICE_SELECT was not enough:
-- it only reorders devices after all drivers are already loaded.
hl.env("VK_DRIVER_FILES", "/usr/share/vulkan/icd.d/intel_icd.json")
