{-# LANGUAGE FlexibleContexts #-}

-- Cohen Sutherland Line Clipping Algorithm
-- https://en.wikipedia.org/wiki/Cohen%E2%80%93Sutherland_algorithm

module Data.Geometry.Clip.Internal.LineCohenSutherland
( clipLineCs
, clipLinesCs
) where

import qualified Data.Aeson                       as Aeson
import qualified Data.Foldable                    as Foldable
import qualified Data.Geospatial                  as Geospatial
import qualified Data.LineString                  as LineString
import qualified Data.Sequence                    as Sequence
import qualified Data.Validation                  as Validation
import           Prelude                          hiding (Left, Right, lines)

import qualified Data.Geometry.Clip.Internal.Line as ClipLine
import qualified Data.Geometry.Types.Geography    as TypesGeography

clipLineCs :: TypesGeography.BoundingBox -> Geospatial.GeoLine -> Geospatial.GeoFeature Aeson.Value -> Sequence.Seq (Geospatial.GeoFeature Aeson.Value) -> Sequence.Seq (Geospatial.GeoFeature Aeson.Value)
clipLineCs bb geoLine feature acc =
  case validLine of
    Validation.Success res -> Geospatial.reWrapGeometry feature (Geospatial.Line (Geospatial.GeoLine res)) Sequence.<| acc
    Validation.Failure _   -> acc
  where
    validLine = clipLineToValidationLineString x
    x = findClipLine bb geoLine

clipLinesCs :: TypesGeography.BoundingBox -> Geospatial.GeoMultiLine -> Geospatial.GeoFeature Aeson.Value -> Sequence.Seq (Geospatial.GeoFeature Aeson.Value) -> Sequence.Seq (Geospatial.GeoFeature Aeson.Value)
clipLinesCs bb lines (Geospatial.GeoFeature bbox _ props fId) acc = checkLinesAndAdd
  where
    checkLinesAndAdd = if Sequence.null multiLine then acc else reMakeFeature Sequence.<| acc
    reMakeFeature = Geospatial.GeoFeature bbox (Geospatial.MultiLine (Geospatial.GeoMultiLine multiLine)) props fId
    multiLine = Foldable.foldl' maybeAddLine mempty (findClipLines bb (Geospatial.splitGeoMultiLine lines))

maybeAddLine :: Sequence.Seq (LineString.LineString Geospatial.GeoPositionWithoutCRS) -> Sequence.Seq TypesGeography.GeoClipLine -> Sequence.Seq (LineString.LineString Geospatial.GeoPositionWithoutCRS)
maybeAddLine acc pp =
  case clipLineToValidationLineString pp of
    Validation.Success res -> res Sequence.<| acc
    Validation.Failure _   -> acc

clipLineToValidationLineString :: Sequence.Seq TypesGeography.GeoClipLine -> Validation.Validation LineString.SequenceToLineStringError (LineString.LineString Geospatial.GeoPositionWithoutCRS)
clipLineToValidationLineString = LineString.fromSeq . ClipLine.segmentToLine . foldPointsToLine

foldPointsToLine :: Sequence.Seq TypesGeography.GeoClipLine -> Sequence.Seq Geospatial.GeoPositionWithoutCRS
foldPointsToLine = Foldable.foldr (mappend . getPoints) mempty

getPoints :: TypesGeography.GeoClipLine -> Sequence.Seq Geospatial.GeoPositionWithoutCRS
getPoints (TypesGeography.GeoClipLine (TypesGeography.GeoClipPoint _ p1) (TypesGeography.GeoClipPoint _ p2)) = Sequence.fromList [Geospatial.GeoPointXY p1, Geospatial.GeoPointXY p2]

findClipLines :: Functor f => TypesGeography.BoundingBox -> f Geospatial.GeoLine -> f (Sequence.Seq TypesGeography.GeoClipLine)
findClipLines bb = fmap (findClipLine bb)

findClipLine :: TypesGeography.BoundingBox -> Geospatial.GeoLine -> Sequence.Seq TypesGeography.GeoClipLine
findClipLine bb line = (Sequence.filter isSame . fmap (evalDiffKeepSame bb)) (outCodeForLineString bb line)

evalDiffKeepSame :: TypesGeography.BoundingBox -> TypesGeography.GeoClipLine -> TypesGeography.GeoClipLine
evalDiffKeepSame bb (TypesGeography.GeoClipLine a@(TypesGeography.GeoClipPoint o1 p1) b@(TypesGeography.GeoClipPoint o2 p2)) =
  case compare o1 o2 of
    GT -> eval $ TypesGeography.GeoClipLine (clipAndCompute o1) b
    LT -> eval $ TypesGeography.GeoClipLine a (clipAndCompute o2)
    EQ -> TypesGeography.GeoClipLine a b
  where
    eval = evalDiffKeepSame bb
    clipAndCompute o = computeNewOutCode $ clipPoint o bb p1 p2
    computeNewOutCode p = TypesGeography.GeoClipPoint (computeOutCode bb p) p

isSame :: TypesGeography.GeoClipLine -> Bool
isSame (TypesGeography.GeoClipLine (TypesGeography.GeoClipPoint o1 _) (TypesGeography.GeoClipPoint o2 _)) =
  case (o1, o2) of
    (TypesGeography.Left   , TypesGeography.Left  ) -> False
    (TypesGeography.Right  , TypesGeography.Right ) -> False
    (TypesGeography.Bottom , TypesGeography.Bottom) -> False
    (TypesGeography.Top    , TypesGeography.Top   ) -> False
    _                                               -> True

clipPoint :: TypesGeography.OutCode -> TypesGeography.BoundingBox -> Geospatial.PointXY -> Geospatial.PointXY -> Geospatial.PointXY
clipPoint outCode (TypesGeography.BoundingBox minX minY maxX maxY) (Geospatial.PointXY x1 y1) (Geospatial.PointXY x2 y2) =
  case outCode of
    TypesGeography.Left   -> Geospatial.PointXY minX (y1 + (y2 - y1) * (minX - x1) / (x2 - x1))
    TypesGeography.Right  -> Geospatial.PointXY maxX (y1 + (y2 - y1) * (maxX - x1) / (x2 - x1))
    TypesGeography.Bottom -> Geospatial.PointXY (x1 + (x2 - x1) * (minY - y1) / (y2 - y1)) minY
    TypesGeography.Top    -> Geospatial.PointXY (x1 + (x2 - x1) * (maxY - y1) / (y2 - y1)) maxY
    _      -> undefined

outCodeForLineString :: TypesGeography.BoundingBox -> Geospatial.GeoLine -> Sequence.Seq TypesGeography.GeoClipLine
outCodeForLineString bb line = fmap (outCodeForLine bb) (ClipLine.getLines line)

outCodeForLine :: TypesGeography.BoundingBox -> TypesGeography.GeoStorableLine -> TypesGeography.GeoClipLine
outCodeForLine bb (TypesGeography.GeoStorableLine p1 p2) = TypesGeography.GeoClipLine toP1 toP2
  where
    toP1 = TypesGeography.GeoClipPoint (computeOutCode bb p1) p1
    toP2 = TypesGeography.GeoClipPoint (computeOutCode bb p2) p2

computeOutCode :: TypesGeography.BoundingBox -> Geospatial.PointXY -> TypesGeography.OutCode
computeOutCode (TypesGeography.BoundingBox minX minY maxX maxY) (Geospatial.PointXY x y)
  | y > maxY  = TypesGeography.Top
  | y < minY  = TypesGeography.Bottom
  | x > maxX  = TypesGeography.Right
  | x < minX  = TypesGeography.Left
  | otherwise = TypesGeography.Inside
