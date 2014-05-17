(in-package :cl-user)
(defpackage :cmacro.parser
  (:use :cl :esrap)
  (:import-from :cmacro.tokens
                :<integer>
                :<identifier>
                :<string>
                :<operator>
                :<variable>)
  (:export :parse-string
           :parse-pathname))
(in-package :cmacro.parser)

;;; Whitespace

(defrule whitespace (+ (or #\Space #\Tab #\Newline #\Linefeed))
  (:constant nil))

;;; Numbers

;; Digits
(defrule octal-digit (or #\0 #\1 #\2 #\3 #\4 #\5 #\6 #\7))

(defrule dec-digit (or #\0 #\1 #\2 #\3 #\4 #\5 #\6 #\7 #\8 #\9))

(defrule hex-digit (or dec-digit
                       #\a #\A #\b #\B #\c #\C #\d #\D #\e #\E #\f #\F))

;; Suffixes

(defrule integer-suffix (+ (or #\l #\L #\u #\U))
  (:constant nil))

(defrule float-suffix (or #\f #\F #\l #\L)
  (:constant nil))

;; Kinds of numbers

(defrule octal (and #\0 (+ octal-digit))
  (:destructure (o digits)
    (text o digits)))

(defrule hex (and #\0 (or #\x #\X) (+ hex-digit))
  (:destructure (o x digits)
    (text o x digits)))

(defrule dec (and (+ dec-digit))
  (:lambda (digits)
    (text digits)))

(defrule integer (and (or octal hex dec) (? integer-suffix))
  (:destructure (num suff)
    (declare (ignore suff))
    (make-instance '<integer> :text num)))

;;; Strings

(defun not-doublequote (char)
  (not (eql #\" char)))

(defrule escape-string (and #\\ #\")
     (:constant nil))

(defrule string-char
    (or escape-string
        (not-doublequote character)))

(defrule string (and (? (or "u8" "u" "U" "L")) #\" (* string-char) #\")
  (:destructure (prefix q1 string q2)
    (declare (ignore prefix q1 q2))
    (make-instance '<string> :text (text string))))

;;; Identifiers

(defrule alphanumeric (alphanumericp character))

(defrule identifier (+ (or alphanumeric #\_))
  (:lambda (list)
    (make-instance '<identifier> :text (coerce list 'string))))

;;; Variables

(defrule var-char (not (or #\( #\))))

(defrule variable (and #\$ #\( (+ var-char) #\))
  (:destructure (dollar open text close)
    (text text)))

;;; Operators

(defun group-separatorp (char)
  (member char (list #\( #\) #\[ #\] #\{ #\}) :test #'char=))

(defrule group-separator (group-separatorp character))

(defrule op-char (not (or alphanumeric group-separator)))

(defrule operator (+ op-char)
  (:lambda (list)
    (make-instance '<operator> :text (coerce list 'string))))

;;; Structure

(defrule atom (or  integer string identifier variable operator))

(defrule list (and #\( (* ast) #\))
  (:destructure (open items close)
    (cons :list (first items))))

(defrule array (and #\[ (* ast) #\])
  (:destructure (open items close)
    (cons :array (first items))))

(defrule block (and #\{ (* ast) #\})
  (:destructure (open items close)
    (cons :block (first items))))

(defrule ast (+ (and (? whitespace) (or atom list array block)))
  (:lambda (items)
    (mapcar #'(lambda (item) (second item)) items)))

(defun parse-string (string)
  (parse 'ast string))

(defun slurp-file (path)
  ;; Credit: http://www.ymeme.com/slurping-a-file-common-lisp-83.html
  (with-open-file (stream path)
    (let ((seq (make-array (file-length stream) :element-type 'character :fill-pointer t)))
      (setf (fill-pointer seq) (read-sequence seq stream))
      seq)))

(defun parse-pathname (pathname)
  (parse 'ast (slurp-file pathname)))
