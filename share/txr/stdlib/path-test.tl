;; Copyright 2015-2016
;; Kaz Kylheku <kaz@kylheku.com>
;; Vancouver, Canada
;; All rights reserved.
;;
;; Redistribution of this software in source and binary forms, with or without
;; modification, is permitted provided that the following two conditions are met.
;;
;; Use of this software in any manner constitutes agreement with the disclaimer
;; which follows the two conditions.
;;
;; 1. Redistributions of source code must retain the above copyright
;;    notice, this list of conditions and the following disclaimer.
;; 2. Redistributions in binary form must reproduce the above copyright
;;    notice, this list of conditions and the following disclaimer in
;;    the documentation and/or other materials provided with the
;;    distribution.
;;
;; THIS SOFTWARE IS PROVIDED ``AS IS'' AND WITHOUT ANY EXPRESS OR IMPLIED
;; WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
;; MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.  IN NO EVENT SHALL THE
;; COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DAMAGES, HOWEVER CAUSED,
;; AND UNDER ANY THEORY OF LIABILITY, ARISING IN ANY WAY OUT OF THE USE OF THIS
;; SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

(defun sys:do-path-test (statfun path testfun)
  [testfun (if (stringp path) (ignerr [statfun path]) path)])

(defmacro sys:path-test ((var statfun path) . body)
  ^[sys:do-path-test ,statfun ,path
     (lambda (,var) (when ,var ,*body))])

(defun sys:path-test-mode (statfun path mask)
  (sys:path-test (s statfun path)
    (plusp (logand s.mode mask))))

(defun path-exists-p (path)
  (sys:path-test (s stat path) t))

(defun path-file-p (path)
  [sys:path-test-mode stat path s-ifreg])

(defun path-dir-p (path)
  [sys:path-test-mode stat path s-ifdir])

(defun path-symlink-p (path)
  [sys:path-test-mode lstat path s-iflnk])

(defun path-blkdev-p (path)
  [sys:path-test-mode stat path s-ifblk])

(defun path-chrdev-p (path)
  [sys:path-test-mode stat path s-ifchr])

(defun path-sock-p (path)
  [sys:path-test-mode stat path s-ifsock])

(defun path-pipe-p (path)
  [sys:path-test-mode stat path s-ififo])

(defun path-setgid-p (path)
  [sys:path-test-mode stat path s-isgid])

(defun path-setuid-p (path)
  [sys:path-test-mode stat path s-isuid])

(defun path-sticky-p (path)
  [sys:path-test-mode stat path s-isvtx])

(defun path-mine-p (path)
  (sys:path-test (s stat path)
    (= s.uid (geteuid))))

(defun path-my-group-p (path)
  (sys:path-test (s stat path)
    (let ((g s.gid))
      (or (= g (getegid))
          (find g (getgroups))))))

(defun sys:path-access (path umask gmask omask)
  (sys:path-test (s stat path)
    (let ((m s.mode)
          (euid (geteuid)))
      (cond
        ((zerop euid) (or (zerop (logior umask s-ixusr))
                          (plusp (logand m (logior umask gmask omask)))))
        ((= euid s.uid) (plusp (logand m umask)))
        ((let ((g s.gid))
           (or (= g (getegid))
               (find g (getgroups))))
         (plusp (logand m gmask)))
        (t (plusp (logand m omask)))))))

(defun path-executable-to-me-p (path)
  (sys:path-access path s-ixusr s-ixgrp s-ixoth))

(defun path-writable-to-me-p (path)
  (sys:path-access path s-iwusr s-iwgrp s-iwoth))

(defun path-private-to-me-p (path)
  (sys:path-test (s stat path)
    (let ((m s.mode)
          (euid (geteuid)))
      (mlet ((g (getgrgid s.gid)))
        (and (eql euid s.uid)
             (zerop (logand m s-iwoth))
             (or (zerop (logand m s-iwgrp))
                 (null g.mem)
                 (and (not (rest g.mem))
                      (equal (getpwuid euid).name (first g.mem)))))))))

(defmacro sys:path-examine ((var statfun path) . body)
  ^[sys:do-path-test ,statfun ,path
     (lambda (,var) ,*body)])

(defun path-newer (path-0 path-1)
  (sys:path-examine (s0 stat path-0)
    (sys:path-examine (s1 stat path-1)
      (and s0 (or (not s1) (> s0.mtime s1.mtime))))))

(defun path-older (path-0 path-1)
  (path-newer path-1 path-0))

(defun path-same-object (path-0 path-1)
  (sys:path-examine (s0 stat path-0)
    (sys:path-examine (s1 stat path-1)
      (and s0 s1
           (eql s0.dev s1.dev)
           (eql s0.ino s1.ino)))))
