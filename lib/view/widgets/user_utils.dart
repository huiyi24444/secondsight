String shortUserId(String userId) {
  return userId.length >= 6
      ? userId.substring(0, 6).toUpperCase()
      : userId.toUpperCase();
}